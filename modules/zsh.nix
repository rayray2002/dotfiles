{ config, lib, pkgs, ... }:
let
  # Shorthands that expand in place when you type a space, so what you see,
  # edit and later find in history is the real command.
  expandingAliases = {
    gst = "git status";
    gco = "git checkout";
    gcmsg = "git commit -m";
    gp = "git push";
    gl = "git pull";
  };

  aliases = {
    l = "eza";
    ls = "eza --icons";
    la = "eza --icons -a";
    ll = "eza --icons -lg";
    lla = "eza --icons -lga";
    tree = "eza --icons -T -a -I .git";
    cat = "bat --paging=never";   # highlight like cat; `bat` itself still pages
    ta = "tmux attach || tmux new-session";   # attach, or start one
    tl = "tmux ls";
    c = "claude --dangerously-skip-permissions";
    cr = "claude --resume";      # pick a past session
    cco = "claude --continue";   # continue the last one here
    # `mamba` is defined in modules/python.nix *after* the micromamba shell hook,
    # because the hook output contains a literal `mamba()` block that collides
    # with a pre-existing `mamba` alias at parse time.
  } // expandingAliases;

  starshipInit = pkgs.runCommand "starship-init.zsh" { } ''
    HOME=$TMPDIR ${lib.getExe config.programs.starship.package} init zsh --print-full-init > $out
  '';

  table = attrs: lib.concatStrings
    (lib.mapAttrsToList (k: v:
      "  ${k}${lib.concatStrings (lib.replicate (17 - lib.stringLength k) " ")}${v}\n") attrs);

  # `zhelp`: the shortcuts this config adds, for when you forget them.
  cheatSheet = pkgs.writeText "zhelp.txt" (''
    Keys
      Up / Down        history entries starting with what you've typed
      Ctrl+R           atuin history search (Enter runs, Tab edits)
      Ctrl+T           fuzzy-insert a file path (bat preview)
      Alt+C            fuzzy cd into a subdirectory (Option-as-Meta on macOS)
      Tab              fuzzy completion menu; < > switch groups
      Ctrl+Space       space without expanding a shorthand
      Ctrl+X Ctrl+E    edit the command line in $EDITOR
      Alt/Ctrl+Arrows  move by word; Home/End to line start/end
    Navigation
      z <part>         jump to a frequent dir (zi: pick with fzf)
      cd -<Tab>        recent directories
      y                yazi file manager; cd's to where you quit
      <dir>            a directory name alone cd's into it
    Shorthands (expand on space)
  '' + table expandingAliases + ''
    Aliases
  '' + table (removeAttrs aliases (builtins.attrNames expandingAliases)) + ''
    Functions
      dots-sync "msg"  commit + push dotfiles and apply them on every host
      dots-status      every host: applied commit, last sync, current/behind/failing
      dots-secret      encrypted shared secrets (set / edit / list / rekey)
      claude-update    bump claude-code now and dots-sync it (codex-update: codex)
      ssh-drop         close reused ssh connections (if one hangs)
      usegpu N         set CUDA_VISIBLE_DEVICES (whichgpu shows it)
      loop 'cmd' secs  rerun cmd every secs, clearing the screen
      mamba            micromamba (create/activate envs)
    Slurm (snoopy): gpus, sgpu, snew, sq, sqa, slog, shist, sk, swatch
    Machine-local settings: ~/.env.zsh
    More: ~/dotfiles/docs (README.md lists them)
  '');
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    syntaxHighlighting.enable = true;
    autocd = true;

    # compaudit + a full $fpath rescan cost ~150 ms per shell. Do that at most
    # once a day; home-manager switch deletes the dump (below), so completions
    # for newly installed packages still show up right away.
    completionInit = ''
      autoload -Uz compinit
      () {
        local dump=''${ZDOTDIR:-$HOME}/.zcompdump
        local -a stale=( ''${dump}(N.mh+24) )
        if [[ ! -s $dump ]] || (( $#stale )); then compinit; else compinit -C; fi
      }
    '';

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      extended = true;              # timestamps in ~/.zsh_history
      share = true;
    };

    shellAliases = aliases;

    # home-manager owns ~/.zprofile; machine-local login settings (e.g. the
    # Mac's `brew shellenv`) live in ~/.zprofile.local, sourced here.
    profileExtra = ''
      [[ -f ~/.zprofile.local ]] && source ~/.zprofile.local
    '';

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # Linux: this config loads compiled modules (fzf-tab) linked against
      # Nix's glibc, so it must run in home-manager's zsh. An interactive zsh
      # that isn't it (Ubuntu's /usr/bin/zsh, an old static zsh on PATH, or
      # tmux starting $SHELL) swaps itself for it before loading anything.
      # _HM_ZSH_SWAPPED stops a loop if the paths ever fail to match.
      (lib.mkOrder 100 (lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        if [[ -o interactive && -z $_HM_ZSH_SWAPPED && -r /proc/$$/exe ]]; then
          () {
            local self=/proc/$$/exe ours=${config.home.profileDirectory}/bin/zsh
            if [[ -x $ours && ''${self:A} != ''${ours:A} ]]; then
              export _HM_ZSH_SWAPPED=1 SHELL=$ours
              [[ -o login ]] && exec $ours -l
              exec $ours
            fi
          }
        fi
      ''))
      (lib.mkOrder 500 ''
        setopt interactivecomments

        # Stop at "/", "_", "."
        WORDCHARS=''${WORDCHARS:s#/#}
        WORDCHARS=''${WORDCHARS:s#_#}
        WORDCHARS=''${WORDCHARS:s#.#}

        # Option/Alt + Left/Right (macOS) and Ctrl + Left/Right (Linux): move by word
        bindkey '^[b' backward-word
        bindkey '^[f' forward-word
        bindkey '^[[1;3D' backward-word
        bindkey '^[[1;3C' forward-word
        bindkey '^[[1;9D' backward-word
        bindkey '^[[1;9C' forward-word
        bindkey '^[[1;5D' backward-word
        bindkey '^[[1;5C' forward-word

        # fn + Left/Right: beginning/end of line
        bindkey '^[[H' beginning-of-line
        bindkey '^[[F' end-of-line
        bindkey '^[[1~' beginning-of-line
        bindkey '^[[4~' end-of-line
        bindkey '^[[7~' beginning-of-line
        bindkey '^[[8~' end-of-line

        # fn + Up/Down: page/history movement
        bindkey '^[[5~' beginning-of-history
        bindkey '^[[6~' end-of-history

        # Up/Down: walk history entries that start with what is already typed
        # (plain history on an empty line). Atuin keeps Ctrl+R.
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        bindkey '^[[A' up-line-or-beginning-search
        bindkey '^[OA' up-line-or-beginning-search
        bindkey '^[[B' down-line-or-beginning-search
        bindkey '^[OB' down-line-or-beginning-search

        # Ctrl+X Ctrl+E: open the command line in $EDITOR
        autoload -Uz edit-command-line
        zle -N edit-command-line
        bindkey '^X^E' edit-command-line
      '')
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

        setopt no_auto_menu
        # cd keeps a stack of recent dirs: `cd -<Tab>` to go back
        setopt auto_pushd pushd_ignore_dups pushd_silent
        # show `!!`/`!$` expansions for confirmation instead of running them
        setopt hist_verify hist_reduce_blanks

        # Completion: offer dotfiles without making every `*` glob match them
        # (as setopt glob_dots did); case-insensitive, then partial-word matching.
        _comp_options+=(globdots)
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:*' switch-group '<' '>'
        zstyle ':fzf-tab:complete:(cd|z|pushd|eza|ls):*' fzf-preview 'eza -1 --color=always --icons $realpath'

        # Shorthands in expandingAliases expand when followed by a space, but
        # only as the first word of a command. Ctrl+Space inserts a plain space.
        _expanding_aliases=(${toString (builtins.attrNames expandingAliases)})
        _expand-alias-space() {
          [[ $LBUFFER =~ "(^|[;|&] *)(''${(j:|:)_expanding_aliases})\$" ]] && zle _expand_alias
          zle self-insert
        }
        zle -N _expand-alias-space
        bindkey ' ' _expand-alias-space
        bindkey '^@' magic-space     # Ctrl+Space
        bindkey -M isearch ' ' magic-space

        (( $+commands[nvim] )) && alias vim=nvim

        # GPU helpers (ported from old .zshrc)
        usegpu() { export CUDA_VISIBLE_DEVICES="$1"; }
        whichgpu() { echo "$CUDA_VISIBLE_DEVICES"; }
        loop() { while true; do eval "$1"; sleep "$2"; clear; done; }

        zhelp() { command cat ${cheatSheet}; }

        # local, machine-specific overrides
        [[ -f ~/.env.zsh ]] && source ~/.env.zsh
      '')
      (lib.mkOrder 2000 ''
        # Starship, then zsh-transient-prompt on top of it: past prompts
        # collapse to a single ❯. The init script is generated at build time.
        [[ $TERM != dumb ]] && source ${starshipInit}

        TRANSIENT_PROMPT_PROMPT='$(starship prompt --terminal-width="$COLUMNS" --keymap="''${KEYMAP:-}" --status="$STARSHIP_CMD_STATUS" --pipestatus="''${STARSHIP_PIPE_STATUS[*]}" --cmd-duration="''${STARSHIP_DURATION:-}" --jobs="$STARSHIP_JOBS_COUNT")'
        TRANSIENT_PROMPT_RPROMPT='$(starship prompt --right --terminal-width="$COLUMNS")'
        TRANSIENT_PROMPT_TRANSIENT_PROMPT="%F{${config.theme.blue}}❯%f "
        TRANSIENT_PROMPT_TRANSIENT_RPROMPT=""

        source ${pkgs.fetchFromGitHub {
          owner = "olets";
          repo = "zsh-transient-prompt";
          rev = "v1.0.1";
          sha256 = "sha256-v4RuB/LL5/6d0FPDPrheFN5o1ZXKjIbfThz/sKSEuII=";
        }}/transient-prompt.zsh-theme
      '')
    ];
  };

  # Starship is sourced above from a build-time script instead of
  # home-manager's `eval "$(starship init zsh)"` (it was initialized twice).
  programs.starship.enableZshIntegration = lib.mkForce false;

  # Fresh completion dump after every switch (see completionInit).
  home.activation.zshCompdump = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -f ${config.home.homeDirectory}/.zcompdump*
  '';
}
