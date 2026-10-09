{ lib, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;

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
      c = "claude --dangerously-skip-permissions";
      gst = "git status";
      gco = "git checkout";
      gcmsg = "git commit -m";
      gp = "git push";
      gl = "git pull";
      # `mamba` is defined in modules/python.nix *after* the micromamba shell hook,
      # because the hook output contains a literal `mamba()` block that collides
      # with a pre-existing `mamba` alias at parse time.
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
      # {
      #   name = "zsh-transient-prompt";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "olets";
      #     repo = "zsh-transient-prompt";
      #     rev = "v1.0.1";
      #     sha256 = "sha256-v4RuB/LL5/6d0FPDPrheFN5o1ZXKjIbfThz/sKSEuII="; 
      #   };
      #   file = "transient-prompt.zsh-theme";
      # }
    ];

    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        setopt interactivecomments

        # Stop at "/", "_", "." 
        WORDCHARS=''${WORDCHARS:s#/#}
        WORDCHARS=''${WORDCHARS:s#_#}
        WORDCHARS=''${WORDCHARS:s#.#}

        # Option/Alt + Left/Right: move by word
        bindkey '^[b' backward-word
        bindkey '^[f' forward-word
        bindkey '^[[1;3D' backward-word
        bindkey '^[[1;3C' forward-word
        bindkey '^[[1;9D' backward-word
        bindkey '^[[1;9C' forward-word

        # fn + Left/Right: beginning/end of line
        bindkey '^[[H' beginning-of-line
        bindkey '^[[F' end-of-line
        bindkey '^[[1~' beginning-of-line
        bindkey '^[[4~' end-of-line
        bindkey '^[[7~' beginning-of-line
        bindkey '^[[8~' end-of-line

        # fn + Up/Down: page/history movement
        bindkey '^[[5~' beginning-of-history
        bindkey '^[[6~' end-of-history      '')
      (lib.mkOrder 550 ''
        # Re-prioritize the Nix profile ahead of anything ~/.zprofile prepended
        # (e.g. `brew shellenv` puts /opt/homebrew/bin first). .zshrc runs after
        # .zprofile, so this is the last word for interactive shells. typeset -U
        # keeps the first occurrence and drops the later duplicate entries.
        typeset -U path PATH
        path=(~/bin ~/.nix-profile/bin /nix/var/nix/profiles/default/bin $path)
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
      (lib.mkOrder 2000 ''
        # 1. Guarantee Starship is initialized first
        eval "$(starship init zsh)"

        # 2. Tell zsh-transient-prompt how to correctly render Starship's full, active prompt
        TRANSIENT_PROMPT_PROMPT='$(starship prompt --terminal-width="$COLUMNS" --keymap="''${KEYMAP:-}" --status="$STARSHIP_CMD_STATUS" --pipestatus="''${STARSHIP_PIPE_STATUS[*]}" --cmd-duration="''${STARSHIP_DURATION:-}" --jobs="$STARSHIP_JOBS_COUNT")'
        TRANSIENT_PROMPT_RPROMPT='$(starship prompt --right --terminal-width="$COLUMNS")'
        
        # 3. Define what the PAST (transient) prompts should collapse down to
        TRANSIENT_PROMPT_TRANSIENT_PROMPT="%F{magenta}❯%f "
        TRANSIENT_PROMPT_TRANSIENT_RPROMPT=""

        # 4. Source the plugin
        source ${pkgs.fetchFromGitHub {
          owner = "olets";
          repo = "zsh-transient-prompt";
          rev = "v1.0.1";
          sha256 = "sha256-v4RuB/LL5/6d0FPDPrheFN5o1ZXKjIbfThz/sKSEuII="; 
        }}/transient-prompt.zsh-theme
      '')
    ];
  };
}