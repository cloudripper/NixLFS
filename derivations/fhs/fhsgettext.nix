{ pkgs, lfsSrcs, cc2 }:
let 
    lib = pkgs.lib;
    stdenv = pkgs.stdenv;

    setupEnvScript= ''
         #!/bin/bash

        chmod u+w /*
        ln -sv bash /usr/bin/sh
        echo "path is $PATH"
        # /usr/bin/bash --login
        # echo $(ls)
# .       cd /tmp/src
        cd /tmp/src
        ./configure --disable-shared
        # env
        exit 1
        cp ./config.log $OUT/tmp.log
        echo $(env) >> env.log
        cp ./env.log $OUT/env.log
        # echo $(cat config.log)

        ./make

        cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

        # echo $(ls /usr/bin)        

        # exit 0

# Come back to this section after system is assembled and before transfering to mnt

        # echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
        # echo "tester:x:101:" >> /etc/group
        # echo $(ls)
        # mkdir /home/tester
        # useradd tester
        # # chown tester:tester /home/tester
        # install -o tester -d /home/tester

# come back to this after assembly 
        cp -pvr /usr $OUT/usr
        cp -pvr /opt $OUT/opt
        cp -pvr /srv $OUT/srv
        cp -pvr /tmp $OUT/tmp
        cp -pvr /boot $OUT/boot
        cp -pvr /home $OUT/home
        cp -pvr /sbin $OUT/sbin
        cp -pvr /root $OUT/root
        cp -pvr /etc $OUT/etc
        cp -pvr /lib $OUT/lib
        cp -pvr /var $OUT/var
        cp -pvr /bin $OUT/bin
        cp -pvr /tools $OUT/tools
        cp -pvr /media $OUT/media
    '';

    fhsEnv = stdenv.mkDerivation {
        name = "fhs-env";

        nativeBuildInputs = with pkgs; [
            xz
        ];

        
        src = pkgs.fetchurl {
            url = lfsSrcs.gettext;
            hash = "sha256-KSF/GBbuLnd/qaAfmVahQTnAwjzBsgNo8GsoiOijQRY=";
        };      
          
        phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

        buildInputs = [ cc2 ];
        
        
        prePhases = "prepEnvironmentPhase";
        prepEnvironmentPhase = ''
            export LFS=$PWD
            export LFSTOOLS=$PWD/tools
            export LFS_TGT=$(uname -m)-lfs-linux-gnu
            export CC2=${cc2}

            cp -r $CC2/* $LFS
            chmod -R u+w $LFS

            # echo $(ls)
            # echo $(ls $LFS/lib)
            # echo $(ls $LFS/usr)
            # echo $(ls $LFS/usr/lib)
            # exit 1
        '';

        configurePhase = ''
            export SRC=$sourceRoot
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

            # src folder
            mkdir -pv $LFS/tmp/src

            cp -rpv $LFS/$SRC/* $LFS/tmp/src
        '';

        buildPhase = ''
            ${pkgs.buildFHSEnv { 
                name = "fhs";     
                extraBwrapArgs = [
                    "--unshare-user"
                    "--unshare-uts"
                    "--hostname lfs-bwap"
                    "--uid 0"
                    "--gid 0"
                    "--chdir /"
                    "--tmpfs /tmp"
                    "--tmpfs /run"
                    "--tmpfs /dev/shm"
                    "--dir /tmp/out"
                    "--dir /tmp/$SRC"
                    # "--dev-bind /dev /lfs/dev
                    # "--dev /lfs/dev"
                    # "--proc /lfs/proc"
                    # "--ro-bind /sys $LFS/sys"
                    # "--ro-bind /run $LFS/run"
                    # "--dir /lfs/root"
                    # "--bind ${fhsEnv}/usr/bin /usr/bin"
                    "--bind $LFS/lib /lib"
                    # "--bind $LFS/usr/lib /lib64"
                    # "--symlink /lib /lib64"
                    # "--bind $LFS/lib64 /lib64"
                    # "--symlink /run /var/run"
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
                    "--bind $out /tmp/out"
                    "--bind $LFS/tmp/src /tmp/src"
                    # "--clearenv"
                    "--setenv HOME /root"
                    "--setenv PATH /usr/bin:/usr/sbin"
                    "--setenv OUT /tmp/out"
                    "--setenv SRC /tmp/src"
                    "--setenv LDFLAGS -L/lib"
                ];
            }}/bin/fhs ${pkgs.writeShellScript "setup" setupEnvScript}; 
            '';
#            #  ${pkgs.buildFHSEnv {
            #     name = "LFSFhs";

            #     # LFS related buildFHSEnv bwrap implementation defaults:
            #     # - bind mounts devtmpfs to /dev, this includes devpts
            #     # - proc to proc
            #     # - 
            #     extraBwrapArgs = [
            #       "--unshare-user"
            #       "--unshare-uts"
            #       "--hostname lfs-bwap"
            #       "--uid 0"
            #       "--gid 0"
            #       "--chdir /"
            #       "--tmpfs /tmp"
            #       # "--dev-bind /dev /lfs/dev
            #       # "--dev /lfs/dev"
            #       # "--proc /lfs/proc"
            #       "--ro-bind /sys /lfs/sys"
            #       "--ro-bind /run /lfs/run"
            #       # "--dir /lfs/root"
            #       # "--bind ${fhsEnv}/usr/bin /usr/bin"
            #       "--bind ${fhsEnv}/lib /lib"
            #       # "--symlink /lib /lib64"
            #       # "--bind ${fhsEnv}/lib64 /lib64"
            #       # "--symlink /run /var/run"
            #       "--setenv HOME /root"
            #       # "--setenv TERM $TERM"
            #       "--bind ${fhsEnv}/root /root"
            #       "--bind ${fhsEnv}/tools /tools"
            #       "--bind ${fhsEnv}/sbin /sbin"
            #       "--bind ${fhsEnv}/bin /bin"
            #       "--bind ${fhsEnv}/usr /usr"
            #       "--bind ${fhsEnv}/var /var"
            #       "--bind ${fhsEnv}/etc /etc"
            #       # "--symlink /usr/bin/bash /usr/bin/sh"
            #       "--setenv PATH /usr/bin:/usr/sbin"
            #       # "--dir /test"
  
            #     ];
            #     # extraOutputsToInstall = ["out" "dev" "man" "doc" "tmp"];
            #     # extraBuildCommands = ''
            #       # echo "BUILDCOMMANDS"
            #       # export TEST="ISNTALL"
            #       # echo $(ls) >> $out/test

            #     # '';   
            #     # extraInstallCommands = ''
            #       # echo "BUILDCOMMANDS"
            #       # export TEST="ISNTALL"
            #       # echo $(ls /) >> $out/test2
            #     # '';
            #     # targetPkgs = pkgs:
            #       # with pkgs; [
            #           # fakeroot
            #           # bash
            #       # ] ++ [ cc2 fhsEnv ];

            #     # runScript = testScript;

            #     # profile = ''
            #       # export HOME=/root
            #       # export TEST="work"
            #      #  cp -rvp ${cc2}/* $LFS
            #       # chmod -R u+w /*
            #       # ln -sv bash /usr/bin/sh
            #       # ln -sfv /run /var/run
            #       # ln -sfv /run/lock /var/lock
            #       # ln -sv /proc/self/mounts /etc/mtab
            #     # '';
            # }}/bin/fhs ${pkgs.writeShellScript "setup" testScript};
        # '';
        
        postInstall = ''
            # mkdir $out
            # cp -vrp $LFS/* $out
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
   in
    fhsEnv
    

