{ config, lib, pkgs, ... }:
let
  routes = import ../ssh/routes.nix;
  spec = name: let v = routes.${name}; in
    if builtins.isList v then { aliases = [ ]; routes = v; } else v;
  names = name: [ name ] ++ (spec name).aliases;
  entries = name: map (r: if builtins.isString r then { addr = r; } else r) (spec name).routes;

  localIps =
    if pkgs.stdenv.isDarwin then "/sbin/ifconfig | awk '/inet /{print $2}'"
    else "ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1";

  # `ssh-probe ADDR`: exit 0 if ADDR answers on port 22 within 1 s. A private
  # address only exists on its own network, so when no local interface shares
  # its prefix (/24 for 192.168, /16 for 10 and 172.16-31) it fails at once
  # instead of waiting out the timeout.
  sshProbe = pkgs.writeShellApplication {
    name = "ssh-probe";
    runtimeInputs = with pkgs; [ netcat gawk coreutils ] ++ lib.optional stdenv.isLinux iproute2;
    text = ''
      addr=$1
      case $addr in
        192.168.*) prefix=''${addr%.*} ;;
        10.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) prefix=''${addr%.*.*} ;;
        *) prefix= ;;
      esac
      if [ -n "$prefix" ]; then
        on_net=
        for ip in $(${localIps}); do
          case $ip in "$prefix".*) on_net=1 ;; esac
        done
        [ -n "$on_net" ] || exit 1
      fi
      exec nc -z -w 1 "$addr" 22 >/dev/null 2>&1
    '';
  };

  # Host names → HostKeyAlias (the name its key is pinned under in
  # ssh/known_hosts), then one `Match host … exec` probe per route and
  # a plain `Host` fallback. `Match host` sees the HostName chosen so far, so
  # once a probe wins the later ones no longer match; `Host` matches the alias,
  # so the fallback block still applies and its ProxyJump is overridden with
  # `none` by whichever probe won.
  block = alias:
    let
      es = entries alias;
      hostPat = toString (names alias);
      matchPat = lib.concatStringsSep "," (names alias);
      probed = lib.init es;
      fallback = lib.last es;
      jumps = lib.any (e: e ? via) es;
      target = e: [ "  HostName ${e.addr}" ]
        ++ lib.optional jumps "  ProxyJump ${e.via or "none"}";
    in
      assert lib.assertMsg (!lib.any (e: e ? via) probed)
        "ssh/routes.nix: ${alias}: only the last route can use `via`";
      lib.concatStringsSep "\n" (
        [ "Host ${hostPat}" "  HostKeyAlias ${alias}" ]
        ++ lib.concatMap (e:
             [ ''Match host ${matchPat} exec "${sshProbe}/bin/ssh-probe ${e.addr}"'' ] ++ target e)
           probed
        ++ [ "Host ${hostPat}" ] ++ target fallback
      );

in
{
  # ssh client config + pinned host keys (NOT private keys). authorized_keys is
  # pushed to servers by ssh/sync-authorized-keys instead of installed here.
  # Sockets for connection reuse (ControlPath in ssh/config).
  home.activation.sshControlDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p -m 700 ${config.home.homeDirectory}/.ssh/cm
  '';
  # Close every reused connection, e.g. after switching networks if one hangs.
  programs.zsh.initContent = ''
    ssh-drop() {
      local s
      for s in ~/.ssh/cm/*(N=); do ssh -o ControlPath=$s -O exit _ 2>/dev/null && print "closed ''${s:t}"; done
    }
  '';

  home.file.".ssh/config".source = ../ssh/config;
  home.file.".ssh/known_hosts.d/dotfiles".source = ../ssh/known_hosts;
  home.file.".ssh/routes.conf".text =
    "# Generated from ssh/routes.nix by modules/ssh.nix; edit those instead.\n\n"
    + lib.concatMapStringsSep "\n\n" block (builtins.attrNames routes) + "\n";
}
