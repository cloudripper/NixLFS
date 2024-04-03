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

  # Attributes for stdenv.mkDerivation can be found at:
  # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
  ncursesPkg = stdenvNoCC.mkDerivation {
    name = "ncurses-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.ncurses;
      hash = "sha256-12pS9gRxi8XmtIlDsCHB5EY8xrImpEz+GaNpi2+JVXk=";
    };

    nativeBuildInputs = [ nativePackages ] ++ [ cc1 ];
    buildInputs = [ cc1 pkgs.gcc ];


    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export CONFIG_SITE=$LFS/usr/share/config.site
      export PATH=$LFSTOOLS/bin:$PATH
      export PATH=$LFS/usr/bin:$PATH
      export CC1=${cc1} 
      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';

    configurePhase = ''
      sed -i s/mawk// configure
      echo $(env | grep TGT)
      echo $(env | grep LD_)
      chmod -R u+w $LFS
    
      mkdir build
      pushd build 
          ../configure 
          make -C include 
          make -C progs tic 
      popd
      export CC=$LFS_TGT-gcc
      export CXX=$LFS_TGT-g++
      ./configure --prefix=/usr        \
          --host=$LFS_TGT              \
          --build=$(./config.guess)    \
          --mandir=/usr/share/man      \
          --with-manpage-format=normal \
          --with-shared                \
          --without-normal             \
          --with-cxx-shared            \
          --without-debug              \
          --without-ada                \
          --disable-stripping          \
          --enable-widec     
    '';

    installPhase = ''
      make DESTDIR=$LFS install TIC_PATH=$(pwd)/build/progs/tic
      
      pushd $LFS/usr/lib
      ln -sv ./libncursesw.so ./libncurses.so
      popd 
      sed -e 's/^#if.*XOPEN.*$/#if 1/' \
          -i $LFS/usr/include/curses.h

      runHook postInstall 
    '';

    postInstall = ''
      mkdir $out
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
ncursesPkg
