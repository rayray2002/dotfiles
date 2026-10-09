{ inputs, pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];

  # oh-my-tmux base config + the user's local overrides
  home.file.".tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
  home.file.".tmux.conf.local".source = ../tmux/.tmux.conf.local;
}
