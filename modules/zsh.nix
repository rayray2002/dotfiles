{ lib, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    shellAliases = {
      l = "eza";
      ls = "eza --icons";
      la = "eza --icons -a";
      ll = "eza --icons -lg";
      lla = "eza --icons -lga";
      tree = "eza --icons -T -a -I .git";
      cat = "bat";
      vim = "nvim";
      ta = "tmux a";
      tl = "tmux ls";
      mamba = "micromamba";
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-abbr";
        src = pkgs.zsh-abbr;
        file = "share/zsh/zsh-abbr/zsh-abbr.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        path=(~/bin $path)
        fpath=(~/.zfunc $fpath)
      '')
      (lib.mkOrder 1000 ''
        export GPG_TTY=$TTY

        setopt glob_dots
        setopt no_auto_menu

        # GPU helpers (ported from old .zshrc)
        usegpu() { export CUDA_VISIBLE_DEVICES="$1"; }
        whichgpu() { echo "$CUDA_VISIBLE_DEVICES"; }
        loop() { while true; do eval "$1"; sleep "$2"; clear; done; }

        # local, machine-specific overrides
        [[ -f ~/.env.zsh ]] && source ~/.env.zsh
      '')
    ];
  };
}
