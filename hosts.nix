# Every machine that runs this flake. The attribute name is the machine's ssh
# alias (ssh/config) and its flake target is "<user>@<name>". dots-sync and the
# auto-sync timer (modules/dots-sync.nix) are generated from this list.
{
  mac         = { system = "aarch64-darwin"; user = "ray"; };
  ray-desktop = { system = "x86_64-linux";   user = "ray"; };
  snoopy      = { system = "x86_64-linux";   user = "borueihu"; };
  xarm        = { system = "x86_64-linux";   user = "ray"; };  # tailnet name: salep
}
