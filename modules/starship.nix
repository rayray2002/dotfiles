{ config, lib, ... }:
let
  c = config.theme;
in
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      format = lib.concatStrings [
        "[](fg:${c.lavender})"
        "$os"
        "[](bg:${c.blue} fg:${c.lavender})"
        "$directory"
        "[](fg:${c.blue} bg:${c.slate})"
        "$git_branch"
        "$git_status"
        "[](fg:${c.slate} bg:${c.navy})"
        "$nodejs"
        "$conda"
        "$bun"
        "$rust"
        "$golang"
        "$php"
        "[](fg:${c.navy} bg:${c.night})"
        "$time"
        "[ ](fg:${c.night})"
        "$line_break"
        "$character"
      ];

      os = {
        disabled = false;
        style = "bg:${c.lavender} fg:${c.ink}";
        format = "[ $symbol ]($style)";

        symbols = {
          Macos = "";
          NixOS = "󱄅";
          Linux = "";
          Ubuntu = "";
          Debian = "";
          Arch = "󰣇";
          Fedora = "󰣛";
          Windows = "󰍲";
          Unknown = "󰟀";
        };
      };

      directory = {
        style = "fg:${c.text} bg:${c.blue}";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";

        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = " ";
          Pictures = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:${c.slate}";
        format = "[[ $symbol $branch ](fg:${c.blue} bg:${c.slate})]($style)";
      };

      git_status = {
        style = "bg:${c.slate}";
        format = "[[($all_status$ahead_behind )](fg:${c.blue} bg:${c.slate})]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($version) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      conda = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($environment) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      bun = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($version) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($version) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($version) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      php = {
        symbol = "";
        style = "bg:${c.navy}";
        format = "[[ $symbol ($version) ](fg:${c.blue} bg:${c.navy})]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:${c.night}";
        format = "[[  $time ](fg:${c.dim} bg:${c.night})]($style)";
      };

      java = {
        disabled = true;
      };
    };
  };
}