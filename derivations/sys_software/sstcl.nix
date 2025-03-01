{ pkgs, lfsSrcs, lfsHashes, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "ss-tcl-env";

    src = pkgs.fetchurl {
      url = lfsSrcs.tcl;
      sha256 = lfsHashes.tcl;
    };

    tclHtmlSrc = builtins.fetchurl {
      url = lfsSrcs.tcl_documentation;
      sha256 = lfsHashes.tcl_documentation;
    };

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

    buildInputs = [ cc2 ];
    nativeBuildInputs = with pkgs; [
      gnutar
      xz
    ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export CC2=${cc2}
      export PATH=$PATH:$LFS/usr/bin
      export CONFIG_SITE=$LFS/usr/share/config.site

      cp -r $CC2/* $LFS
      chmod -R u+w $LFS
    '';

    configurePhase = ''
      export SRC=$PWD
      # Output directory
      mkdir $out
      # src folder
      mkdir -pv $LFS/tmp/src
      cp -vp $tclHtmlSrc $SRC/tcl-html.tar.gz

      cp -rpv $SRC/* $LFS/tmp/src
    '';

    buildPhase = ''
      ${pkgs.buildFHSEnv {
          name = "fhs";

        # This is necessary to override default /lib64 symlink set to /lib.
        # This symlink prevented binding LFS lib to FHS lib64.
        # see setupTargetProfile in buildFHSenv.nix
        # LFS bin interpreter is set to /lib64, so this is important in order
        # for LFS bins to function in FHS env.
        extraBuildCommands = ''
            rm -rf lib64
        '';

        extraBwrapArgs = [
            "--unshare-all"
            "--hostname lfs-bwrap-tcl"
            "--uid 0"
            "--gid 0"
            "--chdir /"
            "--tmpfs /tmp"
            "--tmpfs /run"
            "--tmpfs /dev/shm"
            "--tmpfs /etc"
            "--dir /tmp/out"
              "--dir /build_tools"
            "--bind $out /tmp/out"
            "--bind $LFS/usr/lib /lib64"
            "--bind $LFS/tmp/src /tmp/src"
            "--bind $LFS/usr/lib /lib"
            "--bind $LFS/root /root"
            "--bind $LFS/media /media"
            "--bind $LFS/sbin /sbin"
            "--bind $LFS/bin /bin"
            "--bind $LFS/usr /usr"
            "--bind $LFS/usr/lib /usr/lib"
            "--bind $LFS/var /var"
            "--bind $LFS/etc /etc"
            "--bind $LFS/home /home"
              "--bind $LFS/build_tools /build_tools"
            "--clearenv"
            "--setenv HOME /root"
            "--setenv PATH /usr/bin:/usr/sbin"
            "--setenv OUT /tmp/out"
            "--setenv SRC /tmp/src"
            "--setenv CONFIG_SITE $LFS/usr/share/config.site"
             ];
        }}/bin/fhs ${pkgs.writeShellScript "setup" setupEnvScript};
    '';

    shellHook = ''
      echo -e "\033[31mNix Develop -> $name: Loading...\033[0m"

      if [[ "$(basename $(pwd))" != "$name" ]]; then
          mkdir -p "$name"
          cd "$name"
      fi

      eval "$prepEnvironmentPhase"
      eval "$unpackPhase"
      eval "$configurePhase"
      eval "$buildPhase"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };

  setupEnvScript = ''
    export PATH=/build_tools/bin:$PATH
    set -e
    # trap cleanup ERR
    # cleanup() {
    #   echo "An error occurred. Performing cleanup..."
    #   mkdir $OUT/tmp
    #   cp -pr /tmp/src/*  $OUT/tmp
    #   exit 1
    # }

    cd /tmp/src

    SRCDIR=$(pwd)
    cd unix
    ./configure --prefix=/usr \
                --mandir=/usr/share/man \
                --disable-rpath

    make -j$(nproc)

    sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|" \
        -i tclConfig.sh
    sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.7|/usr/lib/tdbc1.1.7|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/generic|/usr/include|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7|/usr/include|" \
    -i pkgs/tdbc1.1.7/tdbcConfig.sh
    sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.4|/usr/lib/itcl4.2.4|" \
        -e "s|$SRCDIR/pkgs/itcl4.2.4/generic|/usr/include|" \
        -e "s|$SRCDIR/pkgs/itcl4.2.4|/usr/include|" \
        -i pkgs/itcl4.2.4/itclConfig.sh
    unset SRCDIR

    make test

    make install

    # chmod -v u+w /usr/lib/libtcl8.6.so

    make install-private-headers

    ln -sfv tclsh8.6 /usr/bin/tclsh

    mv /usr/share/man/man3/{Thread,Tcl_Thread}.3

    # cd ..
    tar -xf ../tcl-html.tar.gz --strip-components=1 --no-same-owner
    mkdir -v -p /usr/share/doc/tcl-8.6.14
    cp -v -r ./html/* /usr/share/doc/tcl-8.6.14

    set +e
    mkdir $OUT/{usr,opt,srv,tmp,boot,home,sbin,root,etc,lib,var,bin,tools,media,build_tools}
    cp -pvr /usr/* $OUT/usr
    cp -pvr /opt/* $OUT/opt
    cp -pvr /srv/* $OUT/srv
    cp -pvr /boot/* $OUT/boot
    cp -pvr /home/* $OUT/home
    cp -pvr /sbin/* $OUT/sbin
    cp -pvr /root/* $OUT/root
    cp -pvr /etc/* $OUT/etc
    cp -pvr /lib/* $OUT/lib
    cp -pvr /var/* $OUT/var
    cp -pvr /bin/* $OUT/bin
    cp -pvr /media/* $OUT/media
    cp -pvr /build_tools/* $OUT/build_tools
  '';
in
fhsEnv
