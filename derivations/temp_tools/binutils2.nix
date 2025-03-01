{ pkgs, lfsSrcs, lfsHashes, cc1 }:
let
  nixpkgs = pkgs;
  stdenvNoCC = nixpkgs.stdenvNoCC;

  nativePackages = with pkgs; [
    cmake
    texinfo
    zlib
    bison
  ];

  binutils2Pkg = stdenvNoCC.mkDerivation {
    name = "binutils2-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.binutils;
      sha256 = lfsHashes.binutils;
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 pkgs.gcc ];
    # dontFixup = true;

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
          --enable-new-dtags \
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
