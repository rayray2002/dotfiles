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
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      mkHome = system: module:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            # zsh-abbr ships under a non-commercial CC license that nixpkgs
            # marks unfree; permit just that one package for personal use.
            config.allowUnfreePredicate = pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [ "zsh-abbr" ];
          };
          extraSpecialArgs = { inherit inputs; };
          modules = [ module ];
        };
    in {
      homeConfigurations = {
        "ray@mac" = mkHome "aarch64-darwin" ./home/darwin.nix;
        "ray@linux" = mkHome "x86_64-linux" ./home/linux.nix;
      };
    };
}
