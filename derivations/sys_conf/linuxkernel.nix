{ pkgs, lfsSrcs, lfsHashes, kconfig, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  # kernelConfig = pkgs.writeTextFile {
  #   name = "kernel-config";
  #   text = kconfig;
  # };

  fhsEnv = stdenv.mkDerivation {
    name = "linux-kernel-env";

    nativeBuildInputs = with pkgs; [
      xz
      gnutar
    ];

    src = pkgs.fetchurl {
      url = lfsSrcs.linux;
      sha256 = lfsHashes.linux;
    };

    configSrc = kconfig;

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

    buildInputs = [ cc2 ];

    passAsFile = [ "kconfig" ];

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

      # echo setup_config
      # Output directory
      mkdir $out
      # src folder
      mkdir -pv $LFS/tmp/src

      cp -rpv $SRC/.* $LFS/tmp/src
      cp -rpv $SRC/* $LFS/tmp/src

      cp $configSrc/kconfig/.config $LFS/build_tools/.imported_kconfig
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
            "--hostname lfs-bwrap-linux"
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
            "--setenv MAKEFLAGS -j$(nproc)"
            "--setenv OUT /tmp/out"
            "--setenv SRC /tmp/src"
            "--setenv CONFIG_SITE $LFS/usr/share/config.site"
            "--setenv LC_ALL POSIX"
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
      # eval "$configurePhase"
      # eval "$buildPhase"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"

    '';
  };

  setupEnvScript = ''
        export PATH=/build_tools/bin:$PATH
        set -e
        cd /tmp/src

        make mrproper

        cp /build_tools/.imported_kconfig ./.config

        make olddefconfig

        make -j$(nproc)

        make modules_install

        mkdir /boot

        cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.10.5-lfs-12.2-systemd

        cp -iv System.map /boot/System.map-6.10.5

        cp -iv .config /boot/config-6.10.5

        cp -r Documentation -T /usr/share/doc/linux-6.10.5

        install -v -m755 -d /etc/modprobe.d

        cat > /etc/modprobe.d/usb.conf << "EOF"
    # Begin /etc/modprobe.d/usb.conf
    install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
    install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true
    # End /etc/modprobe.d/usb.conf
    EOF

        set +e
        mkdir $OUT/{usr,opt,srv,tmp,boot,home,sbin,root,etc,lib,var,bin,media,dev,sys,proc,run}
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
  '';
in
fhsEnv
