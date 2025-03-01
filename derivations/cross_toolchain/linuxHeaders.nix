{ pkgs, lfsSrcs, lfsHashes, cc1 }:
let
  nixpkgs = pkgs;
  stdenv = nixpkgs.stdenv;

  nativePackages = with pkgs; [
    cmake
    zlib
    bison
    # binutils
  ];


  headersCCPkgs = stdenv.mkDerivation {
    name = "linuxHeaders-LFS";

    src = pkgs.fetchurl {
      url = lfsSrcs.linux;
      sha256 = lfsHashes.linux;
    };

    nativeBuildInputs = [ nativePackages ];
    buildInputs = [ cc1 ];


    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$(pwd)
      export LFSTOOLS=$(pwd)/tools
      export PATH=$LFSTOOLS/bin:$PATH
      export PATH=$LFS/usr/bin:$PATH
      export CONFIG_SITE=$LFS/usr/share/config.site
      export CC1=${cc1}

      chmod -R u+w ./

      cp -r $CC1/* $LFS
      chmod -R u+w $LFS

      mkdir -vp $LFS/usr/{bin,lib,sbin} $LFS/{etc,var}

      case $(uname -m) in
          x86_64) mkdir -pv $LFS/lib64 ;;
      esac
    '';


    configurePhase = ''
      echo "Starting config"
      make mrproper

    '';

    buildPhase = ''
      make headers
    '';

    installPhase = ''
      runHook preInstall

      find ./usr/include -type f ! -name '*.h' -delete

      mkdir $out
      cp -rvp ./usr/include $LFS/usr
      rm -r $LFS/$sourceRoot
      cp -rvp $LFS/* $out/

      runHook postInstall
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
headersCCPkgs
