# Encrypted secrets in the repo (age).
#
# Each host has its own age key at ~/.config/age/dotfiles.key, made on that
# host by `dots-secret init-host` (the private key never leaves it). Public
# keys go in secrets/recipients.txt; secrets are secrets/<name>.age, encrypted
# to every recipient. Declaring one here decrypts it at activation:
#
#   dots.secrets.netrc.target = "${config.home.homeDirectory}/.netrc";
#
# A host that can't decrypt (no key yet, or not a recipient yet) gets a
# warning and keeps going, so a new machine still switches before it's added.
{ config, lib, pkgs, host, ... }:
let
  cfg = config.dots.secrets;
  keyFile = "${config.xdg.configHome}/age/dotfiles.key";
  repoDir = if host.noRoot != null then host.noRoot.flake else "${config.home.homeDirectory}/dotfiles";

  dotsSecret = pkgs.writeShellApplication {
    name = "dots-secret";
    runtimeInputs = with pkgs; [ age coreutils ];
    text = ''
      repo="${repoDir}"
      key="${keyFile}"
      recipients="$repo/secrets/recipients.txt"
      usage() {
        cat <<EOF
      dots-secret init-host     make this host's age key if missing; print its public key
      dots-secret list          secrets in the repo
      dots-secret set NAME      encrypt stdin as secrets/NAME.age (e.g. < ~/.netrc)
      dots-secret edit NAME     decrypt to a temp file, open \$EDITOR, re-encrypt
      dots-secret rekey         re-encrypt every secret to the current recipients
      EOF
      }
      # Plaintext only ever lands in a private temp file that is removed on exit.
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT

      case "''${1:-}" in
        init-host)
          if [ ! -s "$key" ]; then
            mkdir -p "$(dirname "$key")"
            age-keygen -o "$key" 2>/dev/null
            chmod 600 "$key"
          fi
          echo "# ${host.name}"
          age-keygen -y "$key"
          echo "^ add both lines to secrets/recipients.txt, commit, then run 'dots-secret rekey' on a host that can already decrypt" >&2
          ;;
        list)
          for f in "$repo"/secrets/*.age; do [ -e "$f" ] && basename "$f" .age; done
          ;;
        set)
          name=''${2:?usage: dots-secret set NAME < file}
          cat > "$tmp"
          age -e -R "$recipients" -o "$repo/secrets/$name.age" "$tmp"
          echo "wrote secrets/$name.age" >&2
          ;;
        edit)
          name=''${2:?usage: dots-secret edit NAME}
          f="$repo/secrets/$name.age"
          if [ -e "$f" ]; then age -d -i "$key" "$f" > "$tmp"; fi
          "''${EDITOR:-vi}" "$tmp"
          age -e -R "$recipients" -o "$f" "$tmp"
          echo "wrote secrets/$name.age" >&2
          ;;
        rekey)
          for f in "$repo"/secrets/*.age; do
            [ -e "$f" ] || continue
            age -d -i "$key" "$f" > "$tmp"
            age -e -R "$recipients" -o "$f" "$tmp"
            echo "re-encrypted $(basename "$f")" >&2
          done
          ;;
        *) usage ;;
      esac
    '';
  };

  decrypt = name: s: ''
    if [[ -r ${keyFile} ]]; then
      mkdir -p "$(dirname ${s.target})"
      tmp=$(mktemp "$(dirname ${s.target})/.dots-secret.XXXXXX")
      if ${pkgs.age}/bin/age -d -i ${keyFile} -o "$tmp" ${s.file} 2>/dev/null; then
        chmod ${s.mode} "$tmp"
        # A file that was there before this module is kept once, as *.pre-dotfiles.
        if [[ -e ${s.target} && ! -e ${s.target}.pre-dotfiles ]] && ! cmp -s "$tmp" ${s.target}; then
          cp -p ${s.target} ${s.target}.pre-dotfiles
        fi
        if [[ -v DRY_RUN ]]; then rm -f "$tmp"; else mv -f "$tmp" ${s.target}; fi
      else
        rm -f "$tmp"
        warnEcho "secret ${name}: can't decrypt with ${keyFile}; is this host in secrets/recipients.txt? (then dots-secret rekey)"
      fi
    else
      warnEcho "secret ${name}: no age key on this host yet (dots-secret init-host)"
    fi
  '';
in
{
  options.dots.secrets = lib.mkOption {
    default = { };
    description = "Secrets from secrets/<name>.age to decrypt at activation.";
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        file = lib.mkOption {
          type = lib.types.path;
          default = ../secrets + "/${name}.age";
          description = "Encrypted file.";
        };
        target = lib.mkOption {
          type = lib.types.str;
          description = "Where the plaintext goes (absolute path).";
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "0600";
        };
      };
    }));
  };

  config = {
    home.packages = [ pkgs.age dotsSecret ];
    home.activation.dotsSecrets = lib.mkIf (cfg != { })
      (lib.hm.dag.entryAfter [ "writeBoundary" ]
        (lib.concatStrings (lib.mapAttrsToList decrypt cfg)));
  };
}
