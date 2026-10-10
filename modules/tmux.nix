{ config, inputs, lib, pkgs, ... }:
let
  # Loaded in order: continuum finds resurrect through an option resurrect sets.
  plugins = with pkgs.tmuxPlugins; [ resurrect continuum ];
  continuumSave = "${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh";
in
{
  home.packages = [ pkgs.tmux ];

  # oh-my-tmux base config + the user's local overrides, with the Nix plugins
  # appended (see the plugin notes in tmux/.tmux.conf.local)
  home.file.".tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
  home.file.".tmux.conf.local".text =
    builtins.replaceStrings
      ([ "@continuumSave@" ] ++ map (n: "@${n}@") (builtins.attrNames config.theme))
      ([ continuumSave ] ++ builtins.attrValues config.theme)
      (builtins.readFile ../tmux/.tmux.conf.local)
    + "\n# -- plugins (modules/tmux.nix) --\n"
    + lib.concatMapStrings (p: "run-shell ${p.rtp}\n") plugins;

  # A tmux server only accepts clients of its own version: attaching with
  # Nix's tmux to a server started by another build (e.g. Ubuntu's, from
  # before this config, or before an update) fails with the misleading
  # "open terminal failed: not a terminal". Until that server is restarted,
  # talk to it with the binary that started it.
  programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux ''
    tmux() {
      local pid exe
      if [[ -n $TMUX ]]; then
        pid=''${''${(s:,:)TMUX}[2]}
      elif (( ! ''${@[(I)-L|-S]} )); then
        pid=$(ss -Hxlp 2>/dev/null | awk -v s="''${TMUX_TMPDIR:-/tmp}/tmux-$UID/default" \
          '$5 == s && match($0, /pid=[0-9]+/) { print substr($0, RSTART + 4, RLENGTH - 4); exit }')
      fi
      exe=''${pid:+$(readlink /proc/$pid/exe 2>/dev/null)}
      if [[ -n $exe && -x $exe && ''${exe:A} != ''${commands[tmux]:A} ]]; then
        command $exe "$@"
      else
        command tmux "$@"
      fi
    }
  '';
}
