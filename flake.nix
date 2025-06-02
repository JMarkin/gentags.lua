{
  description = "My awesome lua project";


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [ ./nix/development.nix ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # formmatre for `nix fmt`
        formatter = pkgs.nixpkgs-fmt;
      };
    };
}
