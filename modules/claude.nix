# Claude Code, the same on every machine:
# - ~/.claude/CLAUDE.md links to claude/CLAUDE.md in the repo (still writable;
#   memory added from Claude edits the repo file, shared with dots-sync).
# - A few settings are merged into ~/.claude/settings.json at activation:
#   plugins, their marketplaces and the claude-hud status line. Everything else
#   in that file (model, permissions, ...) stays Claude's to change.
{ config, lib, pkgs, host, ... }:
let
  home = config.home.homeDirectory;
  claudeDir = "${home}/.claude";
  repoDir = if host.noRoot != null then host.noRoot.flake else "${home}/dotfiles";

  # claude-hud's status line, with Node from Nix instead of a per-machine path.
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [ nodejs coreutils gawk ];
    text = ''
      cfg=''${CLAUDE_CONFIG_DIR:-$HOME/.claude}
      plugin=$(find "$cfg/plugins/cache" -maxdepth 3 -type d -path '*/claude-hud/*' 2>/dev/null | sort -V | tail -1)
      [ -n "$plugin" ] && [ -f "$plugin/dist/index.js" ] || exit 0
      # no controlling terminal (e.g. when width can't be measured): use 120
      cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}') || true
      cols=''${cols:-120}
      COLUMNS=$(( cols > 4 ? cols - 4 : 1 ))
      export COLUMNS
      exec node "$plugin/dist/index.js"
    '';
  };

  managed = pkgs.writeText "claude-settings.json" (builtins.toJSON {
    enabledPlugins = {
      "claude-hud@claude-hud" = true;
      "superpowers@claude-plugins-official" = true;
      "codex@openai-codex" = true;
      "ralph-loop@claude-plugins-official" = true;
    };
    extraKnownMarketplaces = {
      claude-hud.source = { source = "github"; repo = "jarrodwatts/claude-hud"; };
      openai-codex.source = { source = "github"; repo = "openai/codex-plugin-cc"; };
    };
    statusLine = { type = "command"; command = "${statusline}/bin/claude-statusline"; };
  });
in
{
  home.activation.claudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${claudeDir}
    if [[ ! -v DRY_RUN ]]; then
      f=${claudeDir}/settings.json
      if [[ ! -s $f ]]; then
        cp ${managed} "$f" && chmod 644 "$f"
      elif ${pkgs.jq}/bin/jq -e . "$f" >/dev/null 2>&1; then
        tmp=$(mktemp "$f.XXXXXX")
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$f" ${managed} > "$tmp"
        if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else chmod 644 "$tmp"; mv -f "$tmp" "$f"; fi
      else
        warnEcho "${claudeDir}/settings.json isn't valid JSON; left it alone"
      fi

      md=${claudeDir}/CLAUDE.md
      if [[ -L $md || ! -e $md ]]; then
        ln -sfn ${repoDir}/claude/CLAUDE.md "$md"
      else
        warnEcho "$md is a regular file, not replaced; move its content to claude/CLAUDE.md in the repo"
      fi
    fi
  '';
}
