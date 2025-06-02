{ inputs, ... }:
let
  self = inputs.self;
  nixpkgs = inputs.nixpkgs;
in
{
  flake.overlays.dev = nixpkgs.lib.composeManyExtensions [
    # NOTE: Put development overlays here.
  ];

  perSystem = { system, pkgs-dev, lib, ... }:
    {
      _module.args.pkgs-dev = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.dev ];
      };

      devShells.default = pkgs-dev.mkShell {
        packages = [
          pkgs-dev.nil

          pkgs-dev.stylua
          pkgs-dev.lua-language-server

          pkgs-dev.lua
        ];
      };
    };
}
