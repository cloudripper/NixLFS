{ pkgs, lfsSrcs, cc1 }:
let
  # nixpkgs = import <nixpkgs> {};
  nixpkgs = pkgs;
  stdenvNoCC = nixpkgs.stdenvNoCC;

  nativePackages = with pkgs; [
    cmake
    zlib
    bison
    binutils
  ];

  grepPkg = stdenvNoCC.mkDerivation {
    name = "grep-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.grep;
      hash = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export PATH=$PATH:$LFS/usr/bin
      export PATH=$PATH:$LFSTOOLS/bin
      export CONFIG_SITE=$LFS/usr/share/config.site
      export CC1=${cc1}
 
      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';

    configurePhase = ''
      ./configure --prefix=/usr                   \
          --host=$LFS_TGT                         \
          --build=$(build-aux/config.guess)           
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
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
grepPkg
