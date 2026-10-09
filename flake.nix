{
  description = "ray's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oh-my-tmux = {
      url = "github:gpakosz/.tmux";
      flake = false;
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Separate nixpkgs pin for the Codex CLI: it ships several releases a week,
    # so it gets bumped on its own (`nix flake update nixpkgs-codex`) without
    # dragging the whole world along with the main nixpkgs pin.
    nixpkgs-codex.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      hosts = import ./hosts.nix;
      mkHome = name: h@{ system, user, ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          extraSpecialArgs = {
            inherit inputs hosts;
            host = { noRoot = null; slurm = null; } // h // { inherit name; };
          };
          modules = [
            (if lib.hasSuffix "darwin" system then ./home/darwin.nix else ./home/linux.nix)
          ] ++ lib.optional (builtins.pathExists ./home/hosts/${name}.nix) ./home/hosts/${name}.nix;
        };
    in {
      # One target per machine in hosts.nix, e.g. ray@mac, borueihu@snoopy.
      homeConfigurations =
        lib.mapAttrs' (name: h: lib.nameValuePair "${h.user}@${name}" (mkHome name h)) hosts
        # Legacy names, kept so existing `--flake .#ray@linux` and snoopy's
        # pre-repo hm-switch (builds borueihu@linux) still work.
        // { "ray@linux" = mkHome "linux" { system = "x86_64-linux"; user = "ray"; };
             "borueihu@linux" = mkHome "snoopy" hosts.snoopy; };
    };
}
