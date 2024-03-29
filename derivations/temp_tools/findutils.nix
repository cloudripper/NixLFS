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
  findutilsPkg = stdenvNoCC.mkDerivation {
    name = "findutils-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.findutils;
      hash = "sha256-or+4wJ1DZ3DtxZ9Q+kg+eFsWGjt7nVR1c8sIBl/UYv4=";
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 pkgs.gcc ];

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
          --localstatedir=/var/lib/locate         \
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
findutilsPkg
