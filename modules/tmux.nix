{ inputs, pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];

  # oh-my-tmux base config + the user's local overrides
  home.file.".tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
  home.file.".tmux.conf.local".source = ../tmux/.tmux.conf.local;

  # ssh client config + pinned host keys (NOT private keys). authorized_keys is
  # pushed to servers by ssh/sync-authorized-keys instead of installed here.
  home.file.".ssh/config".source = ../ssh/config;
  home.file.".ssh/known_hosts.d/dotfiles".source = ../ssh/known_hosts;
}
