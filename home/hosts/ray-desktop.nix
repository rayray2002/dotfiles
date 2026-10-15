# ray-desktop-only settings: a Linux desktop with a Windows keyboard and GUI
# terminals, so it also needs the Nerd Fonts (for the prompt and eza icons).
{ lib, pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs.nerd-fonts; [
    jetbrains-mono
    fira-code
    ubuntu-mono
    hack
  ];

  # Ctrl+Backspace / Ctrl+Delete delete a word (the Ctrl+arrows are shared).
  programs.zsh.initContent = lib.mkAfter ''
    bindkey '^H' backward-kill-word
    bindkey '^[[3;5~' kill-word
  '';
}
