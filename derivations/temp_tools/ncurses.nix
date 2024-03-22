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
    binutils
    glibc
  ];

  # Attributes for stdenv.mkDerivation can be found at:
  # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
  ncursesPkg = stdenv.mkDerivation {
    name = "ncurses-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.ncurses;
      hash = "sha256-12pS9gRxi8XmtIlDsCHB5EY8xrImpEz+GaNpi2+JVXk=";
    };

    nativeBuildInputs = [ nativePackages ] ++ [ cc1 ];
    buildInputs = [ cc1 ];


    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export PATH=$LFS/usr/bin:$PATH
      export PATH=$LFSTOOLS/bin:$PATH
      export CC1=${cc1}

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';

    configurePhase = ''
      sed -i s/mawk// configure
      echo $(env | grep TGT)
    
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
      runHook preInstall
      export TIC_PATH=$LFS/$sourceRoot/build/progs/tic

      make DESTDIR=$LFS install
          
      ln -sv $LFS/usr/lib/libncursesw.so $LFS/usr/lib/libncurses.so

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
