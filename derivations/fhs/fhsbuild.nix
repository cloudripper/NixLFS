{ pkgs, cc2 }:
let
  stdenvNoCC = pkgs.stdenvNoCC;

  fhsEnv = stdenvNoCC.mkDerivation {
    name = "fhs-env";
    phases = [ "prepEnvironmentPhase" "configurePhase" "buildPhase" ];

    nativeBuildInputs = with pkgs; [
      coreutils
      bash
    ];

    buildInputs = [ cc2 ];

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
      # Virtual Kernel File Systems
         mkdir -pv $LFS/{dev,proc,sys,run}
      # Additional FHS root-level directories
         mkdir -pv $LFS/{mnt,opt,srv,boot,home,sbin,root,tmp} 
         mkdir -pv $LFS/etc/{opt,sysconfig}
         mkdir -pv $LFS/lib/firmware
         mkdir -pv $LFS/media
         mkdir -pv $LFS/media/{floppy,cdrom}
         mkdir -pv $LFS/usr/{,local/}{include,src}
         mkdir -pv $LFS/usr/local/{bin,sbin,lib}
         mkdir -pv $LFS/{,local/}share/{color,dict,doc,info,locale,man}
         mkdir -pv $LFS/{,local/}share/{misc,terminfo,zoneinfo} 
         mkdir -pv $LFS/{,local/}share/man/man{1..8}
         mkdir -pv $LFS/var/{cache,local,log,mail,opt,spool}
         mkdir -pv $LFS/var/lib/{color,misc,locate}
         mkdir -pv $LFS/var/tmp 
      # Output directory
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
            "--unshare-user"
            "--unshare-uts"
            "--hostname lfs-bwrap"
            "--uid 0"
            "--gid 0"
            "--chdir /"
            "--tmpfs /tmp"
            "--tmpfs /run"
            "--tmpfs /dev/shm"
            "--dir /out"
            "--bind $LFS/usr/bin /usr/bin"
            "--bind $LFS/usr/lib /lib"
            "--bind $LFS/usr/lib /lib64"
            "--bind $LFS/root /root"
            "--bind $LFS/tools /tools"
            "--bind $LFS/media /media"
            "--bind $LFS/sbin /sbin"
            "--bind $LFS/bin /bin"
            "--bind $LFS/usr /usr"
            "--bind $LFS/var /var"
            "--bind $LFS/etc /etc"
            "--bind $LFS/home /home"
            "--bind $out /out"
            "--clearenv"
            "--setenv HOME /root"
            "--setenv PATH /usr/bin:/usr/sbin:/usr/tools/bin"
            "--setenv OUT /out"
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
      eval "$configurePhase"
      eval "$buildPhase"
      echo "loaded"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };


  # FHS Env bash script
  setupEnvScript = ''
      chmod u+w /*
      install -dv -m 0750 /root
      install -dv -m 1777 /tmp /var/tmp

      ln -sv /proc/self/mounts /etc/mtab

            # helix-ignore-start
      cat > /etc/hosts << "EOF"
    127.0.0.1  localhost $(hostname)
    ::1        localhost
    EOF

      cat > /etc/passwd << "EOF"
    root:x:0:0:root:/root:/bin/bash
    bin:x:1:1:bin:/dev/null:/usr/bin/false
    daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
    messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
    systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
    systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
    systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
    systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
    systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
    systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
    systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
    uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
    systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
    nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
    EOF
      # helix-ignore-end
      cat > /etc/group << "EOF"
    root:x:0:
    bin:x:1:daemon
    sys:x:2:
    kmem:x:3:
    tape:x:4:
    tty:x:5:
    daemon:x:6:
    floppy:x:7:
    disk:x:8:
    lp:x:9:
    dialout:x:10:
    audio:x:11:
    video:x:12:
    utmp:x:13:
    cdrom:x:15:
    adm:x:16:
    messagebus:x:18:
    systemd-journal:x:23:
    input:x:24:
    mail:x:34:
    kvm:x:61:
    systemd-journal-gateway:x:73:
    systemd-journal-remote:x:74:
    systemd-journal-upload:x:75:
    systemd-network:x:76:
    systemd-resolve:x:77:
    systemd-timesync:x:78:
    systemd-coredump:x:79:
    uuidd:x:80:
    systemd-oom:x:81:
    wheel:x:97:
    users:x:999:
    nogroup:x:65534:
    EOF

      # Come back to this section after system is assembled and before transfering to mnt

      # echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
      # echo "tester:x:101:" >> /etc/group
      # echo $(ls)
      # mkdir /home/tester
      # useradd tester
      # # chown tester:tester /home/tester
      # install -o tester -d /home/tester

      touch /var/log/btmp
      touch /var/log/lastlog
      touch /var/log/faillog
      touch /var/log/wtmp   
      # echo $(ls /var/log)
      # come back to this after assembly 
      # chgrp -v utmp /var/log/lastlog
      chmod -v 664 /var/log/lastlog
      chmod -v 600 /var/log/btmp

      mkdir $OUT/{usr,opt,srv,tmp,boot,home,sbin,root,etc,lib,var,bin,tools,media}
      cp -pvr /usr/* $OUT/usr
      cp -pvr /opt/* $OUT/opt
      cp -pvr /srv/* $OUT/srv
      cp -pvr /tmp/* $OUT/tmp
      cp -pvr /sbin/* $OUT/sbin
      cp -pvr /etc/* $OUT/etc
      cp -pvr /lib/* $OUT/lib
      cp -pvr /var/* $OUT/var
      cp -pvr /bin/* $OUT/bin
      cp -pvr /tools/* $OUT/tools
      cp -pvr /media/* $OUT/media
  '';
in
fhsEnv
    


