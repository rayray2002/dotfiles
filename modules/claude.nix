# Claude Code and Codex, the same on every machine:
# - ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md link to claude/CLAUDE.md in the
#   repo (still writable; memory added from Claude edits the repo file, shared
#   with dots-sync).
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
    # No "Co-Authored-By: Claude" trailer, PR attribution or session link in
    # commits and PRs (includeCoAuthoredBy is the older name of the same switch).
    attribution = { commit = ""; pr = ""; sessionUrl = false; };
    includeCoAuthoredBy = false;
  });
in
{
  # After noRootEntrypoints so that on rootless hosts ~/.codex is already the
  # link to the real home's (the name is simply ignored elsewhere).
  home.activation.claudeCode = lib.hm.dag.entryAfter [ "writeBoundary" "noRootEntrypoints" ] ''
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

      mkdir -p ${home}/.codex
      ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        # Linux: keep Codex's login in ~/.codex/auth.json. "auto"/"keyring"
        # go through libsecret over D-Bus, which headless servers don't serve
        # (and its entries are keyed by the CODEX_HOME path, which differs
        # inside the rootless env).
        cfgfile=${home}/.codex/config.toml
        if ! grep -qs '^cli_auth_credentials_store' "$cfgfile"; then
          if [[ -s $cfgfile ]]; then
            ${pkgs.gnused}/bin/sed -i '1i cli_auth_credentials_store = "file"' "$cfgfile"
          else
            echo 'cli_auth_credentials_store = "file"' > "$cfgfile"
          fi
        fi
      ''}
      for md in ${claudeDir}/CLAUDE.md ${home}/.codex/AGENTS.md; do
        # replace a link or an empty file; keep anything with content
        if [[ -L $md || ! -s $md ]]; then
          ln -sfn ${repoDir}/claude/CLAUDE.md "$md"
        else
          warnEcho "$md has its own content, not replaced; move it to claude/CLAUDE.md in the repo"
        fi
      done
    fi
  '';
}
