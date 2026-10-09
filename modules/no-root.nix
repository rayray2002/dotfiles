# Machines without root (hosts.nix: noRoot.store), e.g. snoopy.
#
# Nix runs inside a user namespace there: nix-user-chroot bind-mounts
# noRoot.store at /nix (set up by scripts/bootstrap-no-root). Outside that
# namespace /nix does not exist and every home-manager link into /nix/store
# dangles, so the two things read from outside are written as real files at
# activation instead of linked:
#   ~/.zshenv          moves every zsh (ssh login, `ssh host cmd`, scripts)
#                      into the namespace
#   systemd user units dots-sync (hourly pull) and dots-gc (weekly cleanup);
#                      systemd reads unit files from outside
# Everything else (zshrc, ssh and git config, ...) is only read from inside and
# stays a normal home-manager link. zsh's own files move to ~/.config/zsh.
{ config, lib, pkgs, host, ... }:
let
  home = config.home.homeDirectory;
  store = host.noRoot.store;
  nuc = "${home}/.local/bin/nix-user-chroot";
  zdotdir = "${config.xdg.configHome}/zsh";
  bin = "${config.home.profileDirectory}/bin";
  marker = "modules/no-root.nix";

  zshenv = pkgs.writeText "zshenv" ''
    # Written by ${marker}: a real file, not a link into /nix/store.
    if [[ ! -d /nix/store ]]; then
      # Outside the namespace: re-run this same zsh invocation inside it. If
      # that can't work (store missing, or ~/.no-nix exists), carry on as plain
      # system zsh without dotfiles rather than failing the login.
      if [[ ! -e ~/.no-nix && -x ${nuc} && -d ${store}/store ]] && ${nuc} ${store} /bin/true 2>/dev/null; then
        typeset -a _nr_flags
        [[ -o login ]] && _nr_flags+=(-l)
        [[ -o interactive ]] && _nr_flags+=(-i)
        _nr_zsh=''${$(readlink /proc/$$/exe 2>/dev/null):-/bin/zsh}
        if [[ -n $ZSH_EXECUTION_STRING ]]; then
          exec ${nuc} ${store} $_nr_zsh $_nr_flags -c "$ZSH_EXECUTION_STRING"
        elif [[ -n $ZSH_SCRIPT ]]; then
          exec ${nuc} ${store} $_nr_zsh $_nr_flags "$ZSH_SCRIPT" "$@"
        else
          exec ${nuc} ${store} $_nr_zsh $_nr_flags
        fi
      fi
    else
      export ZDOTDIR=${zdotdir}
      source ${zdotdir}/.zshenv
    fi
  '';

  units = pkgs.linkFarm "no-root-units" (lib.mapAttrsToList (name: text: {
    inherit name;
    path = pkgs.writeText name text;
  }) {
    "dots-sync.service" = ''
      [Unit]
      Description=Pull ~/dotfiles from GitHub and apply it (inside nix-user-chroot)

      [Service]
      Type=oneshot
      ExecStart=${nuc} ${store} ${bin}/dots-pull
    '';
    "dots-sync.timer" = ''
      [Unit]
      Description=Hourly dotfiles pull

      [Timer]
      OnCalendar=hourly
      Persistent=true
      RandomizedDelaySec=5m

      [Install]
      WantedBy=timers.target
    '';
    # Old generations would otherwise pile up in the store; keep two weeks.
    "dots-gc.service" = ''
      [Unit]
      Description=Expire old home-manager generations and collect Nix garbage

      [Service]
      Type=oneshot
      ExecStart=${nuc} ${store} /bin/sh -c '${bin}/home-manager expire-generations "-14 days"; ${bin}/nix-collect-garbage --delete-older-than 14d'
    '';
    "dots-gc.timer" = ''
      [Unit]
      Description=Weekly Nix store cleanup

      [Timer]
      OnCalendar=weekly
      Persistent=true
      RandomizedDelaySec=1h

      [Install]
      WantedBy=timers.target
    '';
  });
in
lib.mkIf (host.noRoot != null) {
  assertions = [{
    assertion = pkgs.stdenv.isLinux;
    message = "hosts.nix: noRoot is only supported on Linux (nix-user-chroot)";
  }];

  programs.zsh.dotDir = zdotdir;
  programs.zsh.history.path = "${home}/.zsh_history";
  # home-manager would link ~/.zshenv into the store; ours is a real file.
  home.file.".zshenv".enable = lib.mkForce false;

  home.activation.noRootEntrypoints = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -e $HOME/.zshenv || -L $HOME/.zshenv ]] && ! grep -qs '${marker}' $HOME/.zshenv; then
      run mv $HOME/.zshenv $HOME/.zshenv.pre-dotfiles
    fi
    run install -m 644 ${zshenv} $HOME/.zshenv

    run mkdir -p ${config.xdg.configHome}/systemd/user
    for u in dots-sync.service dots-sync.timer dots-gc.service dots-gc.timer; do
      run install -m 644 ${units}/$u ${config.xdg.configHome}/systemd/user/$u
    done
    if [[ -x /usr/bin/systemctl ]] && /usr/bin/systemctl --user show-environment >/dev/null 2>&1; then
      run /usr/bin/systemctl --user daemon-reload
      run /usr/bin/systemctl --user enable --now dots-sync.timer dots-gc.timer
    else
      warnEcho "no systemd user session; dots-sync/dots-gc timers not enabled"
    fi
  '';
}
