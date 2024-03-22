
{ pkgs, lfsSrcs, cc1 }:
let 
    # nixpkgs = import <nixpkgs> {};
    nixpkgs = pkgs;
    lib = pkgs.lib;
    stdenv = pkgs.stdenv;

    nativePackages = with pkgs; [
        cc1
        bison
        texinfo
        perl
        python3
      ];

    buildPackages = with pkgs; [
        # gnugrep
    ];

    # Attributes for stdenv.mkDerivation can be found at:
    # https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
    libstdCppCCPkg = stdenv.mkDerivation {
        name="libstdcpp-LFS";
        
        src = pkgs.fetchurl {
            url = lfsSrcs.gcc;
            hash = "sha256-4nXnZEKmBnNBon8Exca4PYYTFEAEwEE1KIY9xrXHQ9o=";
        };
        
        
        nativeBuildInputs = [ nativePackages ];
        buildInputs = [ cc1 ];
        
        
        prePhases = "prepEnvironmentPhase";
        prepEnvironmentPhase = ''
            export LFS=$(pwd)
            export LFSTOOLS=$(pwd)/tools
            export LFS_TGT=$(uname -m)-lfs-linux-gnu
            export PATH=$LFS/usr/bin:$PATH
            export PATH=$LFSTOOLS/bin:$PATH
            export CC1=${cc1}
            export CC=$LFS_TGT-gcc
            export CXX=$LFS_TGT-g++
            cp -r $CC1/* $LFS
            chmod -R u+w $LFS

            # cp -r $LFSTOOLS/x86_64-lfs-linux-gnu $LFS/.
            # cp -rvp $LFS/usr/lib64/* $LFS/tools/x86_64-lfs-linux-gnu/lib
            # cp -r --update=none  $LFS/usr/lib64/* $LFS/lib

            # echo 'int main(){}' | $LFS_TGT-gcc -xc -
            # readelf -l a.out | grep ld-linux
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
                            --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0 \
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