{ pkgs, lfsSrcs, cc1 }:

let
  stdenv = pkgs.stdenv;

  nativePackages = with pkgs; [
    zlib
    bison
  ];

  gcc2Pkg = stdenv.mkDerivation {
    name = "gcc2-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.gcc;
      hash = "sha256-4nXnZEKmBnNBon8Exca4PYYTFEAEwEE1KIY9xrXHQ9o=";
    };

    secondarySrcs = [
      (pkgs.fetchurl {
        url = lfsSrcs.mpfr;
        sha256 = "277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2";
      })
      (pkgs.fetchurl {
        url = lfsSrcs.gmp;
        sha256 = "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898";
      })
      (pkgs.fetchurl {
        url = lfsSrcs.mpc;
        sha256 = "ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8";
      })
    ];

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 pkgs.binutils ];

    prePhases = "prepEnvironmentPhase";

    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export CC1=${cc1}
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export PATH=$PATH:$LFS/usr/bin
      export PATH=$PATH:$LFSTOOLS/bin
      export CONFIG_SITE=$LFS/usr/share/config.site
 
      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';

    # Adding mpc, gmp, and mpfr to gcc source repo.
    patchPhase = ''
      export SOURCE=/build/$sourceRoot
            
      for secSrc in $secondarySrcs; do
          case $secSrc in
          *.xz)
              tar -xJf $secSrc -C ../$sourceRoot/
              ;;
          *.gz)
              tar -xzf $secSrc -C ../$sourceRoot/
              ;;
          *)
              echo "Invalid filetype: $secSrc"
              exit 1
              ;;
          esac

          srcDir=$(echo $secSrc | sed 's/^[^-]*-\(.*\)\.tar.*/\1/') 
          echo "Src: $srcDir"
          newDir=$(echo $secSrc | cut -d'-' -f2) 
          echo "newDir: $newDir"
          mv -v ./$srcDir ./$newDir
      done


      case $(uname -m) in
          x86_64)
              sed -e '/m64=/s/lib64/lib/' \
              -i.orig gcc/config/i386/t-linux64
      ;;
      esac

      sed '/thread_header =/s/@.*@/gthr-posix.h/' \
          -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
    '';

    # CFLAGS and CXXFLAGS added to dodge string literal warning error.
    configurePhase = ''

      echo "Starting config"
      mkdir -v build
      cd build
      ../configure                                        \
              --prefix=/usr                               \
              --build=$(../config.guess)                  \
              --host=$LFS_TGT                             \
              --target=$LFS_TGT                           \
              LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc    \
              --with-build-sysroot=$LFS         \
              --enable-default-pie        \
              --enable-default-ssp        \
              --disable-nls               \
              --disable-multilib          \
              --disable-libatomic         \
              --disable-libgomp           \
              --disable-libquadmath       \
              --disable-libsanitizer       \
              --disable-libssp            \
              --disable-libvtv            \
              --enable-languages=c,c++    \
              CFLAGS='-Wno-error=format-security' \
              CXXFLAGS='-Wno-error=format-security' 
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      echo "Install complete."
            
      cp -vr gcc $LFS/usr/bin/cc
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
      eval "$unpackPhase"
      eval "$patchPhase"
      eval "$configurePhase"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };
in
gcc2Pkg
