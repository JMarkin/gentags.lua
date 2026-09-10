{ system ? builtins.currentSystem
}:
let
  pins = import ./npins;
  pkgs = import pins.nixpkgs {
    inherit system;
    overlays = [ ];
  };
  inherit (pkgs) stdenv lib;

in
pkgs.mkShell {
  packages = with pkgs; [
    # lua
    stylua
    lua-language-server
    universal-ctags

    # nix
    npins
    nixd
    nixpkgs-fmt
  ];

}

