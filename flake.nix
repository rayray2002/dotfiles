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
      mkHome = name: { system, user }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            # zsh-abbr ships under a non-commercial CC license that nixpkgs
            # marks unfree; permit just that one package for personal use.
            config.allowUnfreePredicate = pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [ "zsh-abbr" ];
          };
          extraSpecialArgs = { inherit inputs hosts; host = { inherit name system user; }; };
          modules = [
            (if lib.hasSuffix "darwin" system then ./home/darwin.nix else ./home/linux.nix)
          ];
        };
    in {
      # One target per machine in hosts.nix, e.g. ray@mac, borueihu@snoopy.
      homeConfigurations =
        lib.mapAttrs' (name: h: lib.nameValuePair "${h.user}@${name}" (mkHome name h)) hosts
        # Legacy generic target, kept so existing `--flake .#ray@linux` still works.
        // { "ray@linux" = mkHome "linux" { system = "x86_64-linux"; user = "ray"; }; };
    };
}
