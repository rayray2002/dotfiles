{ inputs, pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];

  # oh-my-tmux base config + the user's local overrides
  home.file.".tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
  home.file.".tmux.conf.local".source = ../tmux/.tmux.conf.local;

  # ssh client config (NOT private keys; authorized_keys intentionally left out)
  home.file.".ssh/config".source = ../ssh/config;
}
