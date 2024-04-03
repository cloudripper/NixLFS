{ pkgs, lfsSrcs, cc1 }:
let
  nixpkgs = pkgs;
  stdenvNoCC = nixpkgs.stdenvNoCC;

  nativePackages = with pkgs; [
    cmake
    zlib
    bison
    binutils
  ];

  # Attributes for stdenv.mkDerivation can be found at:
  # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
  bashPkg = stdenvNoCC.mkDerivation {
    name = "bash-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.bash;
      hash = "sha256-yOMb3Fm2mq/8WzZQmQW6Ply7EnRwkdJ7S5d/B4Vg1bg=";
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 pkgs.gcc ];


    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export CONFIG_SITE=$LFS/usr/share/config.site
      export PATH=$LFSTOOLS/bin:$PATH
      export CC1=${cc1} 

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';


    configurePhase = ''
      ./configure --prefix=/usr                   \
          --host=$LFS_TGT                         \
          --build=$(sh ./support/config.guess)    \
          --without-bash-malloc
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      mkdir $LFS/bin

      pushd $LFS/usr
      ln -sv ./bin/bash ../bin/sh
      popd

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
bashPkg
