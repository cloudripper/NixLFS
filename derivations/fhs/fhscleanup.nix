{ pkgs, lfsSrcs, cc2, lib }:

(pkgs.buildFHSEnv {
  name = "my-fhs-environment";
  targetPkgs = pkgs: [
    # Add packages necessary for your work here
    pkgs.coreutils # for chgrp, chmod, etc.
    # fhsUtilLinuxStage
    # LFS
    pkgs.shadow

  ] ++ [ cc2 ];
  multiPkgs = pkgs: [
    # Packages to be available from the global environment
  ];
  runScript = "bash"; # or another shell of your choice

  extraBwrapArgs = [
    "--unshare-all"
    # "--unshare-user"
    # "--unshare-uts"
    "--hostname lfs-bwrap"
    "--uid 0"
    "--gid 0"
    "--chdir /"
    # "--tmpfs /tmp"
    # "--tmpfs /run 
    # "--tmpfs /dev/shm"
    # "--tmpfs /etc"
    # "--dir /tmp/out"
    # "--dir /tmp/bin"
    # # "--perms 777"
    # "--dir /mnt"
    # # "--bind $LFS/usr/lib /lib"
    # # "--bind $LFS/usr/lib /lib64"
    # "--bind $LFS/root /root"
    # "--bind $LFS/media /media"
    # "--bind $LFS/sbin /sbin"
    # "--bind $LFS/bin /bin"
    # # "--bind $LFS/usr /usr"
    # # "--bind $LFS/usr/lib /usr/lib"
    # "--bind $LFS/var /var"
    "--bind ${cc2}/etc /etc"
    # "--bind $LFS/home /home"
    # "--bind $out /tmp/out"
    # "--bind /mnt/lfs /mnt/lfs"
    "--clearenv"
    "--setenv HOME /root"
    "--setenv PATH $PATH:/usr/bin:/usr/sbin"
    "--setenv OUT /tmp/out"
    "--setenv CONFIG_SITE $LFS/usr/share/config.site"
  ];
}).env

