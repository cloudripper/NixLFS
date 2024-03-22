
{ pkgs, lfsSrcs, cc1 }:
let 
    # nixpkgs = import <nixpkgs> {};
    nixpkgs = pkgs;
    lib = pkgs.lib;
    stdenv = pkgs.stdenv;

    nativePackages = with pkgs; [
        bison
        texinfo
        perl
        python3
        glibc
      ];

    

    # Attributes for stdenv.mkDerivation can be found at:
    # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
    glibcPkg = stdenv.mkDerivation {
        name="glibc-LFS";
        
        src = pkgs.fetchurl {
            url = lfsSrcs.glibc;
            hash = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
        };

        patchSrc = pkgs.fetchurl {
                url = lfsSrcs.glibc_patch;
                sha256 = "277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2";
        };
        
        
        nativeBuildInputs = [ nativePackages ];
        buildInputs = [ cc1 ];
        
        
        prePhases = "prepEnvironmentPhase";
        prepEnvironmentPhase = ''
            export LFS=$PWD
            export LFSTOOLS=$LFS/tools
            export LFS_TGT=$(uname -m)-lfs-linux-gnu
            export CC1=${cc1}

            cp -r $CC1/* $LFS/
            chmod -R u+w $LFS
        '';

        configurePhase = ''
            export PATH=$LFSTOOLS/bin:$PATH
            export CC=$LFS_TGT-gcc
            
            case $(uname -m) in
                i?86)   ln -sfv ${pkgs.glibc}/lib/ld-linux.so.2 $LFS/lib/ld-lsb.so.3
                ;;
                x86_64) ln -sfv ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $LFS/lib64
                        ln -sfv ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
                ;;
            esac

            echo "rootsbindir=/usr/sbin" > configparms

            mkdir -v build
            cd build

           ../configure                              \
                --prefix=/usr                        \
                --host=$LFS_TGT                      \
                --build=$(../scripts/config.guess)   \
                --enable-kernel=4.19                 \
                --with-headers=$LFS/usr/include      \
                --disable-nscd                       \
                libc_cv_slibdir=/usr/lib
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
    glibcPkg