{ inputs, lib, pkgs, ... }:
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
    builtins.replaceStrings [ "@continuumSave@" ] [ continuumSave ]
      (builtins.readFile ../tmux/.tmux.conf.local)
    + "\n# -- plugins (modules/tmux.nix) --\n"
    + lib.concatMapStrings (p: "run-shell ${p.rtp}\n") plugins;
}
