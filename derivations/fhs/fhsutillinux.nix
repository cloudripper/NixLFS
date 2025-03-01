{ pkgs, lfsSrcs, lfsHashes, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "fhs-util-linux-env";

    nativeBuildInputs = with pkgs; [
      xz
      gnutar
    ];

    src = pkgs.fetchurl {
      url = lfsSrcs.util_linux;
      sha256 = lfsHashes.util_linux;
    };

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export LFSTOOLS=$PWD/tools
      export LFS_TGT=$(uname -m)-lfs-linux-gnu
      export CC2=${cc2}
      export PATH=$PATH:$LFS/usr/bin
      export PATH=$PATH:$LFSTOOLS/bin
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
              "--hostname lfs-bwap"
              "--uid 0"
              "--gid 0"
              "--chdir /"
              "--tmpfs /tmp"
              "--tmpfs /run"
              "--tmpfs /dev/shm"
              "--dir /tmp/out"
              "--dir /build_tools"
              "--dir /tmp/bin"
              "--bind $LFS/usr/lib /lib"
              "--bind $LFS/usr/lib /lib64"
              "--bind $LFS/root /root"
              "--bind $LFS/tools /tools"
              "--bind $LFS/media /media"
              "--bind $LFS/sbin /sbin"
              "--bind $LFS/bin /bin"
              "--bind $LFS/usr /usr"
              "--bind $LFS/usr/lib /usr/lib"
              "--bind $LFS/var /var"
              "--bind $LFS/etc /etc"
              "--bind $LFS/home /home"
              "--bind $LFS/build_tools /build_tools"
              "--bind $out /tmp/out"
              "--bind $LFS/tmp/src /tmp/src"
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
    cd /tmp/src

    # disable-use-tty-group is set due to mkderiv/bwrap chgrp challenge
    # disable-makeinstall-setuid for same reason
    ./configure --libdir=/usr/lib \
                --runstatedir=/run \
                --disable-chfn-chsh \
                --disable-login \
                --disable-nologin \
                --disable-su \
                --disable-setpriv \
                --disable-runuser \
                --disable-pylibmount \
                --disable-static \
                --disable-liblastlog2 \
                --without-python \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/util-linux-2.40.2 \
               || exit 1

    make -j$(nproc) || exit 1

    make install || exit 1

    rm -rf /usr/share/{info,man,doc}/*
    find /usr/{lib,libexec} -name \*.la -delete
    rm -rf /tools

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
