{ pkgs, lfsSrcs, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "sys-conf-env";

    phases = [ "prepEnvironmentPhase" "buildPhase" ];

    buildInputs = [ cc2 ];

    prePhases = "prepEnvironmentPhase";
    prepEnvironmentPhase = ''
      export LFS=$PWD
      export CC2=${cc2}
      export PATH=$PATH:$LFS/usr/bin
      export CONFIG_SITE=$LFS/usr/share/config.site

      cp -r $CC2/* $LFS
      chmod -R u+w $LFS

      mkdir $out
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
            "--hostname lfs-bwrap-sys-conf"
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
      eval "$buildPhase"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };

  setupEnvScript = ''
        export PATH=/build_tools/bin:$PATH
        # set -e

        # cleanup - stripping
        save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
                      libc.so.6
                      libthread_db.so.1
                      libquadmath.so.0.0.0
                      libstdc++.so.6.0.32
                      libitm.so.1.0.0
                      libatomic.so.1.2.0"

        cd /usr/lib

        for LIB in $save_usrlib; do
          objcopy --only-keep-debug --compress-debug-sections=zlib $LIB $LIB.dbg
          cp $LIB /tmp/$LIB
          strip --strip-unneeded /tmp/$LIB
          objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
          install -vm755 /tmp/$LIB /usr/lib
          rm /tmp/$LIB
        done

        online_usrbin="bash find strip"

        online_usrlib="libbfd-2.42.so
          libsframe.so.1.0.0
          libhistory.so.8.2
          libncursesw.so.6.4
          libm.so.6
          libreadline.so.8.2
          libz.so.1.3.1
          libzstd.so.1.5.5
          $(cd /usr/lib; find libnss*.so* -type f)"

        for BIN in $online_usrbin; do
          cp /usr/bin/$BIN /tmp/$BIN
          strip --strip-unneeded /tmp/$BIN
          install -vm755 /tmp/$BIN /usr/bin
          rm /tmp/$BIN
        done

        for LIB in $online_usrlib; do
          cp /usr/lib/$LIB /tmp/$LIB
          strip --strip-unneeded /tmp/$LIB
          install -vm755 /tmp/$LIB /usr/lib
          rm /tmp/$LIB
        done

        for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
                 $(find /usr/lib -type f -name \*.a) \
                 $(find /usr/{bin,sbin,libexec} -type f); do
          case "$online_usrbin $online_usrlib $save_usrlib" in
            *$(basename $i)* )
              ;;
            * ) strip --strip-unneeded $i
              ;;
          esac
        done

        unset BIN LIB save_usrlib online_usrbin online_usrlib    

        # cleanup
        rm -rf /tmp/*
        find /usr/lib /usr/libexec -name \*.la -delete

        find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf



        # sys config
        set -e

        # default network device naming
        ln -s /dev/null /etc/systemd/network/99-default.link

    #     # Static IP config
    #     cat > /etc/systemd/network/10-eth-static.network << "EOF"
    # [Match]
    # Name=<network-device-name>

    # [Network]
    # Address=192.168.102.1
    # Gateway=192.168.1.4
    # EOF

        # DHCP Conf
        cat > /etc/systemd/network/10-eth-dhcp.network << "EOF"
    [Match]
    Name=<network-device-name>

    [Network]
    DHCP=ipv4

    [DHCPv4]
    UseDomains=true
    EOF

        cat > /etc/resolv.conf << "EOF"
    # Begin /etc/resolv.conf

    # domain <eg> 
    nameserver 192.168.1.4

    # End /etc/resolv.conf
    EOF
        # System hostname
        echo "devix" > /etc/hostname

        cat > /etc/hosts << "EOF"
    # Begin /etc/hosts

    127.0.0.1 localhost
    ::1       ip6-localhost ip6-loopback
    ff02::1   ip6-allnodes
    ff02::2   ip6-allrouters

    # End /etc/hosts
    EOF

        # Device and module handling

        # Config sys clock - hwclock set to UTC, so system will auto confi adjtime
        # Console config

        cat > /etc/locale.conf << "EOF"
    LANG=en_US.UTF-8
    LC_ADDRESS=en_US.UTF-8
    LC_IDENTIFICATION=en_US.UTF-8
    LC_MEASUREMENT=en_US.UTF-8
    LC_MONETARY=en_US.UTF-8
    LC_NAME=en_US.UTF-8
    LC_NUMERIC=en_US.UTF-8
    LC_PAPER=en_US.UTF-8
    LC_TELEPHONE=en_US.UTF-8
    LC_TIME=en_US.UTF-8
    EOF

        cat > /etc/profile << "EOF"
    # Begin /etc/profile
    for i in $(locale); do
    unset ''${i%=*}
    done
    if [[ "$TERM" = linux ]]; then
    export LANG=C.UTF-8
    else
    source /etc/locale.conf
    for i in $(locale); do
    key=''${i%=*}
    if [[ -v $key ]]; then
    export $key
    fi
    done
    fi
    # End /etc/profile
    EOF

        cat > /etc/inputrc << "EOF"
    # Begin /etc/inputrc
    # Modified by Chris Lynn <roryo@roryo.dynup.net>
    # Allow the command prompt to wrap to the next line
    set horizontal-scroll-mode Off
    # Enable 8-bit input
    set meta-flag On
    set input-meta On
    # Turns off 8th bit stripping
    set convert-meta Off
    # Keep the 8th bit for display
    set output-meta On
    # none, visible or audible
    set bell-style none
    # All of the following map the escape sequence of the value
    # contained in the 1st argument to the readline specific functions
    "\eOd": backward-word
    "\eOc": forward-word
    # for linux console
    "\e[1~": beginning-of-line
    "\e[4~": end-of-line
    "\e[5~": beginning-of-history
    "\e[6~": end-of-history
    "\e[3~": delete-char
    "\e[2~": quoted-insert
    # for xterm
    "\eOH": beginning-of-line
    "\eOF": end-of-line
    # for Konsole
    "\e[H": beginning-of-line
    "\e[F": end-of-line
    # End /etc/inputrc
    EOF
    
        cat > /etc/shells << "EOF"
    # Begin /etc/shells
    /bin/sh
    bin/bash
    # End /etc/shells
    EOF
    
        # Systemd config
        # disable clear screen at boot time
        mkdir -pv /etc/systemd/system/getty@tty1.service.d
        cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << "EOF"
    [Service]
    TTYVTDisallocate=no
    EOF

        # This disabled tmpfs for /tmp
        # ln -sfv /dev/null /etc/systemd/system/tmp.mount

        # /etc/fstab config file
        cat > /etc/fstab << "EOF"
    # Begin /etc/fstab

    # File_system  mount_point  type  options         dump     fsck order

    /dev/ext4      /            defaults              1        1

    # Enf of /etc/fstab
    EOF

    
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
          
    
