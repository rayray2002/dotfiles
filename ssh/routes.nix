# How to reach each multi-route ssh alias, preferred first:
#   LAN (home/lab) → Tailscale → school / jump host.
# ssh uses the first entry whose port 22 answers; the LAST entry is the
# fallback and is never probed. A LAN entry costs nothing when you are not on
# that network (ssh-probe skips it unless a local interface shares its prefix);
# any other probed entry costs up to 1 s when it is down.
# An entry is an address, or { addr = ...; via = "<jump alias>"; } (last only).
# A host is a list of entries, or { aliases = [ ... ]; routes = [ ... ]; } when
# it answers to more names; all of them share one route and one host key,
# pinned in ssh/known_hosts under the attribute name (used as HostKeyAlias).
# Generated into ~/.ssh/routes.conf by modules/ssh.nix; User and other options
# stay in ssh/config.
{
  xarm = {
    aliases = [ "salep" ];   # its tailnet name
    routes = [
      "10.137.31.180"        # lab LAN
      "100.119.115.83"       # tailnet
    ];
  };
  snoopy = [
    "10.137.35.135"      # lab LAN, direct
    "100.71.153.128"     # tailnet (rootless tailscaled)
    { addr = "10.137.35.135"; via = "xarm"; }  # lab LAN through xarm
  ];
  ray-desktop = [
    "192.168.12.204"     # home LAN
    "100.122.59.69"      # tailnet
  ];
  # Franka/Panda workstation; the two logins are different users.
  "glamor-citrine" = {
    aliases = [ "glamor_panda_shared" "glamor_panda_ray" ];
    routes = [
      "10.23.74.233"         # lab LAN
      "100.78.42.34"         # tailnet (glamor-citrine)
    ];
  };
}
