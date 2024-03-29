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
  filePkg = stdenvNoCC.mkDerivation {
    name = "file-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.file;
      hash = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
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
      mkdir build
      cd build
          ../configure                \
              --disable-bzlib         \
              --disable-libseccomp    \
              --disable-xzlib         \
              --disable-zlib 
          make
      cd ..

      export CC=$LFS_TGT-gcc
      export CXX=$LFS_TGT-g++
 
      ./configure                     \
          --prefix=/usr               \
          --host=$LFS_TGT             \
          --build=$(./config.guess)   
    '';

    # buildFlags = [ "FILE_COMPILE=$LFS/$sourceRoot/build/src/file" ];

    buildPhase = ''
      make  FILE_COMPILE=$LFS/$sourceRoot/build/src/file
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      rm -v $LFS/usr/lib/libmagic.la
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
filePkg
