{ pkgs, cc2 }:
let 
    lib = pkgs.lib;
    stdenv = pkgs.stdenv;

    fhsEnv = stdenv.mkDerivation {
        name = "fhs-env";
        phases = [ "prepEnvironmentPhase" "configurePhase" "postInstall" ];

        buildInputs = [ cc2 ];
        
        
        prePhases = "prepEnvironmentPhase";
        prepEnvironmentPhase = ''
            export LFS=$PWD
            export LFSTOOLS=$PWD/tools
            export LFS_TGT=$(uname -m)-lfs-linux-gnu
            export PATH=$LFS/usr/bin:$PATH
            export PATH=$LFSTOOLS/bin:$PATH
            export CC2=${cc2}

            cp -r $CC2/* $LFS
            chmod -R u+w $LFS
        '';

        configurePhase = ''
           mkdir -pv $LFS/{dev,proc,sys,run,mnt,opt,srv,boot,home,sbin} 
           mkdir -pv $LFS/etc/{opt,sysconfig}
           mkdir -pv $LFS/lib/firmware
           mkdir -pv $LFS/media/{floppy,cdrom}
           mkdir -pv $LFS/usr/{,local/}{include,src}
           mkdir -pv $LFS/usr/local/{bin,sbin,lib}
           mkdir -pv $LFS/{,local/}share/{color,dict,doc,info,locale,man}
           mkdir -pv $LFS/{,local/}share/{misc,terminfo,zoneinfo} 
           mkdir -pv $LFS/{,local/}share/man/man{1..8}
           mkdir -pv $LFS/var/{cache,local,log,mail,opt,spool}
           mkdir -pv $LFS/var/lib/{color,misc,locate}

           mkdir -pv $LFS/root
           mkdir -pv $LFS/tmp 
           mkdir -pv $LFS/var/tmp 
        '';
        
        postInstall = ''
            mkdir $out
            cp -vrp $LFS/* $out
        '';
    };
   in
    let

    testScript = ''
     #!/bin/bash
       # cp -pvr /usr /mnt/lfs/usr
      touch $out/test3
    '';

    
      fhs = (pkgs.buildFHSEnv {
        name = "LFSFhs";

        # LFS related buildFHSEnv bwrap implementation defaults:
        # - bind mounts devtmpfs to /dev, this includes devpts
        # - proc to proc
        # - 
        
        extraBwrapArgs = [
          "--unshare-user"
          "--unshare-uts"
          "--hostname lfs-bwap"
          "--uid 0"
          "--gid 0"
          "--chdir /"
          "--tmpfs /tmp"
          "--bind /nix /nix"
          "--dir /root"
          # "--dev-bind /dev /lfs/dev
          # "--dev /lfs/dev"
          # "--proc /lfs/proc"
          "--ro-bind /sys /lfs/sys"
          "--ro-bind /run /lfs/run"
          # "--dir /lfs/root"
          # "--bind ${fhsEnv}/usr/bin /usr/bin"
          "--bind ${fhsEnv}/lib /lib"
          # "--symlink /lib /lib64"
          # "--bind ${fhsEnv}/lib64 /lib64"
          # "--symlink /run /var/run"
          "--setenv HOME /root"
          "--bind ${fhsEnv}/root /root"
          "--bind ${fhsEnv}/tools /tools"
          "--bind ${fhsEnv}/sbin /sbin"
          "--bind ${fhsEnv}/bin /bin"
          "--bind ${fhsEnv}/usr /usr"
          "--bind ${fhsEnv}/var /var"
          "--bind ${fhsEnv}/etc /etc"
          "--clearenv"
          # "--symlink /usr/bin/bash /usr/bin/sh"
          "--setenv PATH /usr/bin:/usr/sbin"
  
        ];
        # extraOutputsToInstall = ["out" "dev" "man" "doc" "tmp"];
        extraBuildCommands = ''
          export HOME=/root
          echo $(ls) >> $out/test
          # chmod -R u+w /*
          # chmod -R u+w /root
          # chmod -R u+w /tools
          # chmod -R u+w /bin
          # chmod -R u+w /usr
          # chmod -R u+w /var
          # chmod -R u+w /etc
          # chmod -R u+w /tmp
          # ln -sfv /run /var/run
          # ln -sfv /run/lock /var/lock
          # ln -sv /proc/self/mounts /etc/mtab
        '';   

        extraInstallCommands = ''
        '';

        targetPkgs = pkgs:
          with pkgs; [
              # fakeroot
              # bash
          ] ++ [ cc2 fhsEnv ];

        # runScript = testScript;

        profile = ''
          export TEST="work"
         #  cp -rvp ${cc2}/* $LFS
        '';

        
    }).env;
    
  in 
    fhs

