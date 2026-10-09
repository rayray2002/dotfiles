{ config, lib, pkgs, host, hosts, ... }:
let
  flakeDir = "${config.home.homeDirectory}/dotfiles";
  target = "${host.user}@${host.name}";
  # Anonymous https, so the background timer needs no ssh agent or keys.
  publicRemote = "https://github.com/rayray2002/dotfiles.git";
  stateDir = "${config.xdg.stateHome}/dots-sync";
  # "mac ray@mac ray-desktop ray@ray-desktop ..." for a zsh associative array.
  syncTargets = lib.concatStringsSep " "
    (lib.mapAttrsToList (name: h: "${name} ${h.user}@${name}") hosts);

  # Fast-forward main from GitHub and run home-manager switch if HEAD is not the
  # last applied commit. Refuses to touch a dirty tree or a non-main branch, and
  # leaves the reason in $stateDir/error so the next shell prints it.
  # Run by the timer, by dots-sync on every host, and by hand.
  # runtimeInputs pins the tools so it works under systemd/launchd's bare PATH.
  dotsPull = pkgs.writeShellApplication {
    name = "dots-pull";
    runtimeInputs = with pkgs; [ nix git home-manager openssh cacert coreutils ];
    text = ''
      state="${stateDir}"
      mkdir -p "$state"
      fail() { echo "dots-pull: $*" >&2; echo "$*" > "$state/error"; exit 1; }
      trap 'fail "failed at line $LINENO; run dots-pull to see why"' ERR

      cd "${flakeDir}"
      branch=$(git branch --show-current)
      [ "$branch" = main ] || fail "${flakeDir} is on '$branch', not main"
      if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        fail "uncommitted changes in ${flakeDir}; run dots-sync to publish them"
      fi

      if [ "''${1:-}" != --no-fetch ]; then
        git fetch --quiet "${publicRemote}" +main:refs/remotes/origin/main
        git merge --ff-only --quiet origin/main || fail "local main has diverged from origin/main"
      fi

      head=$(git rev-parse HEAD)
      if [ "$head" = "$(cat "$state/applied" 2>/dev/null)" ]; then
        echo "dots-pull: up to date ($(git log --oneline -1))"
      else
        echo "dots-pull: applying $(git log --oneline -1)"
        home-manager switch --flake "${flakeDir}#${target}"
        echo "$head" > "$state/applied"
      fi
      rm -f "$state/error"
    '';
  };

  # Units point at the profile path rather than the store path, so their
  # definition never changes and home-manager doesn't reload the unit while
  # it is the one running the switch.
  dotsPullBin = "${config.home.profileDirectory}/bin/dots-pull";
in
{
  home.packages = [ dotsPull ];

  programs.zsh.initContent = lib.mkOrder 1000 ''
    # Publish local dotfiles edits and apply them everywhere: commit tracked
    # changes, switch here first (a broken config never gets pushed), push,
    # then run dots-pull on every other host in hosts.nix over ssh, in parallel.
    # Hosts that are off/unreachable catch up via the hourly dots-sync timer.
    dots-sync() {
      setopt local_options no_monitor
      local -A targets=( ${syncTargets} )
      local h untracked logs=${stateDir}
      (
        cd ${flakeDir} || exit 1
        if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
          git add -u && git commit -q -m "''${1:-sync from ${host.name}}" || exit 1
        fi
        untracked=$(git ls-files --others --exclude-standard)
        [[ -n $untracked ]] && print -P "%F{yellow}not synced (untracked; git add them first):%f\n$untracked"
        dots-pull --no-fetch || exit 1
        git pull --rebase --quiet && git push --quiet || exit 1
        dots-pull || exit 1
      ) || return 1
      for h in ''${(k)targets}; do
        [[ $h == ${host.name} ]] && continue
        # Hosts still on a pre-dots-sync config have no dots-pull yet.
        ( ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new $h \
            "export PATH=\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH
             if command -v dots-pull >/dev/null; then dots-pull
             else cd ~/dotfiles && git pull --ff-only && home-manager switch --flake ~/dotfiles#''${targets[$h]}; fi" \
            &>$logs/$h.log && print "✓ $h" || print "✗ $h  ($logs/$h.log)" ) &
      done
      wait
    }

    # Bump claude-code now instead of waiting for the daily CI bump
    # (.github/workflows/update-claude-code.yml), and sync it everywhere.
    claude-update() {
      ( cd ${flakeDir} && nix flake update claude-code ) && dots-sync "flake.lock: bump claude-code"
    }

    [[ -s ${stateDir}/error ]] && print -P "%F{yellow}dotfiles auto-sync: $(<${stateDir}/error)%f"
  '';

  home.activation.dotsSyncState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${stateDir}
  '';

  # Without root these units are written as real files by modules/no-root.nix.
  systemd.user = lib.mkIf (pkgs.stdenv.isLinux && host.noRoot == null) {
    services.dots-sync = {
      Unit.Description = "Pull ~/dotfiles from GitHub and apply it with home-manager";
      Service = {
        Type = "oneshot";
        ExecStart = dotsPullBin;
      };
    };
    timers.dots-sync = {
      Unit.Description = "Hourly dotfiles pull";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;          # catch up if the machine was off
        RandomizedDelaySec = "5m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  launchd.agents.dots-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ dotsPullBin ];
      # Hourly. No RunAtLoad: loading happens mid-activation and would start a
      # second switch concurrently.
      StartInterval = 3600;
      StandardOutPath = "${config.home.homeDirectory}/.cache/dots-sync.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/dots-sync.log";
    };
  };
}
