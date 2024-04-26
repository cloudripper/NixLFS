{ pkgs, lfsSrcs, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "ss-systemd-env";

    src = builtins.fetchTarball {
      url = lfsSrcs.systemd;
      sha256 = "1qdyw9g3jgvsbc1aryr11gpc3075w5pg00mqv4pyf3hwixxkwaq6";
    };

    patchSrc = builtins.fetchurl {
      url = lfsSrcs.systemd_patch;
      sha256 = "1j4xx8j0sif5nl3mxkdc2xskj3xb2w3qv9n1yqkjhp2vf31gx78k";
    };

    manpagesSrc = builtins.fetchurl {
      url = lfsSrcs.systemd_manpages;
      sha256 = "0p36vs1smiji379i794hr9h07bvfpiv1ybxy3qqc9g1rf4mm6m6j";
    };

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

    buildInputs = [ cc2 ];

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

      cp -vp $patchSrc $SRC/systemd-255-upstream_fixes-1.patch

      cp -vrp $manpagesSrc $SRC/systemd-man-pages-255.tar.xz
      
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
            rm lib64
        '';

        extraBwrapArgs = [
            "--unshare-all"
            "--hostname lfs-bwrap-systemd"
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
            "--setenv MAKEFLAGS -j$(nproc)"
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
    cd /tmp/src

    sed -i -e 's/GROUP="render"/GROUP="video"/' \
        -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in

    patch -Np1 -i ./systemd-255-upstream_fixes-1.patch
    mkdir -p build
    cd build
    meson setup \
          --prefix=/usr \
          --buildtype=release \
          -Ddefault-dnssec=no \
          -Dfirstboot=false \
          -Dinstall-tests=false \
          -Dldconfig=false \
          -Dsysusers=false \
          -Drpmmacrosdir=no \
          -Dhomed=disabled \
          -Duserdb=false \
          -Dman=disabled \
          -Dmode=release \
          -Dpamconfdir=no \
          -Ddev-kvm-mode=0660 \
          -Dnobody-group=nogroup \
          -Dsysupdate=disabled \
          -Dukify=disabled \
          -Ddocdir=/usr/share/doc/systemd-255 \
          ..

    ninja

    ninja install

    tar -xf ../systemd-man-pages-255.tar.xz \
        --no-same-owner --strip-components=1 \
        -C /usr/share/man

    systemd-machine-id-setup

    systemctl preset-all
    
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
          
    
