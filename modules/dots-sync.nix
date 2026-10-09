{ config, lib, pkgs, host, hosts, ... }:
let
  noRoot = host.noRoot != null;
  flakeDir = if noRoot then host.noRoot.flake else "${config.home.homeDirectory}/dotfiles";
  target = "${host.user}@${host.name}";
  # Without root, building goes through nix-portable (modules/no-root.nix).
  switchCmd = if noRoot then "${host.noRoot.location}/bin/hm-switch"
    else ''home-manager switch --flake "${flakeDir}#${target}"'';
  # Anonymous https, so the background timer needs no ssh agent or keys.
  publicRemote = "https://github.com/rayray2002/dotfiles.git";
  stateDir = "${config.xdg.stateHome}/dots-sync";
  # "mac ray@mac ray-desktop ray@ray-desktop ..." for a zsh associative array.
  syncTargets = lib.concatStringsSep " "
    (lib.mapAttrsToList (name: h: "${name} ${h.user}@${name}") hosts);
  # Each host's dots-sync state dir, as the remote shell should expand it
  # (rootless hosts keep their home-manager home elsewhere).
  statePaths = lib.concatStringsSep " " (lib.mapAttrsToList (name: h:
    "${name} ${if (h.noRoot or null) != null then "${h.noRoot.home}/.local/state/dots-sync"
               else "'$HOME/.local/state/dots-sync'"}") hosts);
  # Prints "<applied commit>|<last successful check>|<error>" for one host.
  statusProbe = pkgs.writeText "dots-status-probe" ''
    eval "s=$1"
    a=$(cut -c1-7 "$s/applied" 2>/dev/null)
    c=$(date -r "$s/checked" '+%m-%d %H:%M' 2>/dev/null)
    e=$(head -c 100 "$s/error" 2>/dev/null | tr '|\n' '  ')
    printf '%s|%s|%s\n' "$a" "$c" "$e"
  '';
  # Extra PATH for `ssh <host> dots-pull`: rootless hosts keep it in <location>/bin.
  remotePaths = lib.concatStringsSep " " (lib.mapAttrsToList (name: h:
    "${name} ${if (h.noRoot or null) != null then "${h.noRoot.location}/bin" else "-"}") hosts);

  # Fast-forward main from GitHub and switch if HEAD is not the last applied
  # commit. Refuses to touch a dirty tree or a non-main branch, and leaves the
  # reason in $stateDir/error so the next shell prints it.
  # Run by the timer, by dots-sync on every host, and by hand.
  dotsPullBody = ''
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
      ${switchCmd}
      echo "$head" > "$state/applied"
    fi
    rm -f "$state/error"
    date > "$state/checked"
  '';

  # runtimeInputs pins the tools so it works under systemd/launchd's bare PATH.
  dotsPull = pkgs.writeShellApplication {
    name = "dots-pull";
    runtimeInputs = with pkgs; [ nix git home-manager openssh cacert coreutils ];
    text = dotsPullBody;
  };

  # Units point at the profile path rather than the store path, so their
  # definition never changes and home-manager doesn't reload the unit while
  # it is the one running the switch.
  dotsPullBin = "${config.home.profileDirectory}/bin/dots-pull";
in
{
  # Without root the store is only visible inside nix-portable, so there
  # dots-pull is a plain script on system bash/git, installed as a real file
  # by modules/no-root.nix.
  options.dots.pullScript = lib.mkOption {
    type = lib.types.str;
    internal = true;
    default = "#!/usr/bin/env bash\nset -euo pipefail\n" + dotsPullBody;
  };

  config = {
    home.packages = lib.optional (!noRoot) dotsPull;

    programs.zsh.initContent = lib.mkOrder 1000 ''
      # Publish local dotfiles edits and apply them everywhere: commit tracked
      # changes, switch here first (a broken config never gets pushed), push,
      # then run dots-pull on every other host in hosts.nix over ssh, in parallel.
      # Hosts that are off/unreachable catch up via the hourly dots-sync timer.
      dots-sync() {
        setopt local_options no_monitor
        local -A targets=( ${syncTargets} ) rpath=( ${remotePaths} )
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
              "export PATH=''${''${rpath[$h]:#-}:+''${rpath[$h]}:}\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH
               if command -v dots-pull >/dev/null; then dots-pull
               elif command -v home-manager >/dev/null; then cd ~/dotfiles && git pull --ff-only && home-manager switch --flake ~/dotfiles#''${targets[$h]}
               else echo 'dotfiles not set up here (no dots-pull or home-manager)'; exit 1; fi" \
              &>$logs/$h.log && print "✓ $h" || print "✗ $h  ($logs/$h.log)" ) &
        done
        wait
      }

      # One line per host: the commit it last applied, when its sync last ran
      # cleanly, and whether it is current with GitHub's main or stuck.
      dots-status() {
        setopt local_options no_monitor
        local -A state=( ${statePaths} )
        local tmp=$(mktemp -d) h head a c e line
        git -C ${flakeDir} fetch --quiet ${publicRemote} +main:refs/remotes/origin/main 2>/dev/null
        head=$(git -C ${flakeDir} rev-parse --short=7 origin/main)
        for h in ''${(k)state}; do
          (
            if [[ $h == ${host.name} ]]; then line=$(sh ${statusProbe} "''${state[$h]}")
            else line=$(ssh -o ConnectTimeout=5 -o BatchMode=yes $h sh -s -- "''${state[$h]}" < ${statusProbe} 2>/dev/null) || line="!unreachable"
            fi
            print -r -- "$line" > $tmp/$h
          ) &
        done
        wait
        print -P "%BGitHub main: $head%b"
        printf '%-18s %-8s %-12s %s\n' host applied last-check status
        for h in ''${(ko)state}; do
          IFS='|' read -r a c e < $tmp/$h
          if [[ $a == '!unreachable' ]]; then line="%F{red}✗ unreachable%f"; a=; c=
          elif [[ -n $e ]]; then line="%F{red}✗ $e%f"
          elif [[ -z $a ]]; then line="%F{yellow}· never applied%f"
          elif [[ $a == $head ]]; then line="%F{green}✓ current%f"
          else line="%F{yellow}↻ behind main%f"
          fi
          printf '%-18s %-8s %-12s ' $h "''${a:--}" "''${c:--}"; print -P -- "$line"
        done
        rm -r -- $tmp
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
    systemd.user = lib.mkIf (pkgs.stdenv.isLinux && !noRoot) {
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
  };
}
