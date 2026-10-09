{ lib, ... }:
{
  # One palette for the prompt (modules/starship.nix) and tmux
  # (tmux/.tmux.conf.local, filled in by modules/tmux.nix), so they match.
  # Colours of starship's "Tokyo Night" preset; red is Tokyo Night's for alerts.
  options.theme = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    readOnly = true;
    description = "Shared colour palette (hex).";
    default = {
      lavender = "#a3aed2";
      blue = "#769ff0";
      slate = "#394260";
      navy = "#212736";
      night = "#1d2230";
      text = "#e3e5e5";
      dim = "#a0a9cb";
      ink = "#090c0c";
      red = "#f7768e";
    };
  };
}
