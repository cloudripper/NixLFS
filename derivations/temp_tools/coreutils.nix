{ pkgs, lfsSrcs, cc1 }:
let
  # nixpkgs = import <nixpkgs> {};
  nixpkgs = pkgs;
  lib = nixpkgs.lib;
  stdenv = nixpkgs.stdenv;

  nativePackages = with pkgs; [
    cmake
    zlib
    bison
  ];


  coreutilsPkg = stdenv.mkDerivation {
    name = "coreutils-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.coreutils;
      hash = "sha256-6mE6TPRGEjJukXIBu7zfvTAd4h/8O1m25cB+BAsnXlI=";
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export PATH=$LFS/usr/bin:$PATH
      export PATH=$LFSTOOLS/bin:$PATH
      export PATH=${pkgs.coreutils}/bin:$PATH
      export CC1=${cc1}
      export CC=$LFS_TGT-gcc
      export CXX=$LFS_TGT-g++

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';


    configurePhase = ''
      ./configure --prefix=/usr                   \
          --host=$LFS_TGT                         \
          --build=$(build-aux/config.guess)       \
          --enable-install-program=hostname      \
          --enable-no-install-program=kill,uptime
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      echo "Install complete."
      mv -v $LFS/usr/bin/chroot               $LFS/usr/sbin
      mkdir -pv $LFS/usr/share/man/man8
      mv -v $LFS/usr/share/man/man1/chroot.1  $LFS/usr/share/man/man8/chroot.8
      sed -i 's/"1"/"8"/'                     $LFS/usr/share/man/man8/chroot.8

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
coreutilsPkg
