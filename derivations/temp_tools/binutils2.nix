{ pkgs, lfsSrcs, cc1 }:
let
  # nixpkgs = import <nixpkgs> {};
  nixpkgs = pkgs;
  lib = nixpkgs.lib;
  stdenv = nixpkgs.stdenv;

  nativePackages = with pkgs; [
    cmake
    texinfo
    zlib
    bison
  ];

  # Attributes for stdenv.mkDerivation can be found at:
  # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
  binutils2Pkg = stdenv.mkDerivation {
    name = "binutils2-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.binutils;
      hash = "sha256-9uTUH9X8d4sGt4kUV7NiDaXs6hAGxqSkGumYEJ+FqAA=";
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 ];
    depsBuildBuild = [ cc1 ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export PATH=$PATH:$LFS/usr/bin
      export PATH=$PATH:$LFSTOOLS/bin
      export PATH=$PATH:$LFSTOOLS/$LFS_TGT/bin
      export CC1=${cc1}
      export CC=$LFS_TGT-gcc
      export CXX=$LFS_TGT-g++

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';


    configurePhase = ''

      sed '6009s/$add_dir//' -i ltmain.sh

      mkdir -v build
      cd build

      ../configure \
          --prefix=/usr \
          --build=$(../config.guess) \
          --host=$LFS_TGT \
          --disable-nls \
          --enable-shared \
          --enable-gprofng=no \
          --disable-werror \
          --enable-64-bit-bfd \
          --enable-default-hash-style=gnu
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
      rm -r $LFS/$sourceRoot
      cp -rvp $LFS/* $out/
    '';

    shellHook = ''
      echo -e "\033[31mNix Develop -> $name: Loading...\033[0m"

      if [[ "$(basename $(pwd))" != "$name" ]]; then
          mkdir -p "$name"
          cd "$name"
      fi

      eval "$prepEnvironmentPhase"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };
in
binutils2Pkg
