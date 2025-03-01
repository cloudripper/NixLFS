{ pkgs, lfsSrcs, lfsHashes, cc1 }:
let
  # nixpkgs = import <nixpkgs> {};
  stdenvNoCC = pkgs.stdenvNoCC;

  nativePackages = with pkgs; [
    bison
    texinfo
    perl
    python3
  ];


  # Attributes for stdenv.mkDerivation can be found at:
  # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
  libstdCppCCPkg = stdenvNoCC.mkDerivation {
    name = "libstdcpp-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.gcc;
      sha256 = lfsHashes.gcc;
    };


    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 ];

    dontFixup = true;
    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$(pwd)
      export LFSTOOLS=$(pwd)/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export CONFIG_SITE=$LFS/usr/share/config.site
      export PATH=$LFSTOOLS/bin:$PATH
      export PATH=$LFS/usr/bin:$PATH
      export CC1=${cc1}

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS
    '';

    configurePhase = ''
       mkdir -v build
       cd build

      ../libstdc++-v3/configure                        \
                       --prefix=/usr                  \
                       --host=$LFS_TGT                 \
                       --build=$(uname -m)-pc-linux-gnu \
                       --disable-multilib              \
                       --disable-nls                   \
                       --disable-libstdcxx-pch         \
                       --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/14.2.0 \
                       CFLAGS='-fpermissive' \
                       CXXFLAGS='-fpermissive'
    '';

    installFlags = [ "DESTDIR=$(LFS)" ];

    postInstall = ''
      rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
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
libstdCppCCPkg
