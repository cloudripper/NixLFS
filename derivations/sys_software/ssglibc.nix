{ pkgs, lfsSrcs, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "fhs-glibc-env";

    src = builtins.fetchTarball {
      url = lfsSrcs.glibc;
      sha256 = "0zr0lk75rvkxp0xplfsggaj4fcv1xjpsvg5qrvp6yifim77q2mn0";
    };

    patchSrc = builtins.fetchurl {
      url = lfsSrcs.glibc_patch;
      sha256 = "03bvq857ajfvxdb0wbjayfmkyggqyph5ixg4zmzjsbqf0gdm4db4";
    };

    tzdataSrc = builtins.fetchurl {
      url = lfsSrcs.tzdata2024a;
      sha256 = "1qzzxnv059gziwjccsgdys8nba4498qg78cdgad0blnbk92k810d";
    };



    phases = [ "prepEnvironmentPhase" "unpackPhase" "patchPhase" "configurePhase" "buildPhase" ];

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


    patchPhase = ''
      cp $patchSrc glibc-2.39-fhs-1.patch
    '';

    configurePhase = ''
      export SRC=$PWD
      # Output directory
      mkdir $out
      # src folder
      mkdir -pv $LFS/tmp/src

      # copy tz data to source root
      cp $tzdataSrc ./tzdata2024a.tar.gz

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
            "--hostname lfs-bwrap"
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
        cd /tmp/src

        patch -Np1 -i ./glibc-2.39-fhs-1.patch 

        mkdir -v build
        cd build

        echo "rootsbindir=/usr/sbin" > configparams

        ../configure --prefix=/usr \
                    --disable-werror \
                    --enable-kernel=4.19 \
                    --enable-stack-protector=strong \
                    --disable-nscd \
                    libc_cv_slibdir=/usr/lib

        make

        make check

        # Prevent ld.so.conf warning
        touch /etc/ld.so.conf

        sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

        make install

        sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

        mkdir -pv /usr/lib/locale
        localedef -i C -f UTF-8 C.UTF-8
        localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
        localedef -i de_DE -f ISO-8859-1 de_DE
        localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
        localedef -i de_DE -f UTF-8 de_DE.UTF-8
        localedef -i el_GR -f ISO-8859-7 el_GR
        localedef -i en_GB -f ISO-8859-1 en_GB
        localedef -i en_GB -f UTF-8 en_GB.UTF-8
        localedef -i en_HK -f ISO-8859-1 en_HK
        localedef -i en_PH -f ISO-8859-1 en_PH
        localedef -i en_US -f ISO-8859-1 en_US
        localedef -i en_US -f UTF-8 en_US.UTF-8
        localedef -i es_ES -f ISO-8859-15 es_ES@euro
        localedef -i es_MX -f ISO-8859-1 es_MX
        localedef -i fa_IR -f UTF-8 fa_IR
        localedef -i fr_FR -f ISO-8859-1 fr_FR
        localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
        localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
        localedef -i is_IS -f ISO-8859-1 is_IS
        localedef -i is_IS -f UTF-8 is_IS.UTF-8
        localedef -i it_IT -f ISO-8859-1 it_IT
        localedef -i it_IT -f ISO-8859-15 it_IT@euro
        localedef -i it_IT -f UTF-8 it_IT.UTF-8
        localedef -i ja_JP -f EUC-JP ja_JP
        localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
        localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
        localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
        localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
        localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
        localedef -i se_NO -f UTF-8 se_NO.UTF-8
        localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
        localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
        localedef -i zh_CN -f GB18030 zh_CN.GB18030
        localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
        localedef -i zh_TW -f UTF-8 zh_TW.UTF-8i


        cat > /etc/nsswitch.conf << "EOF"
    # Begin /etc/nsswitch.conf
    passwd: files systemd
    group: files systemd
    shadow: files systemd
    hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
    networks: files
    protocols: files
    services: files
    ethers: files
    rpc: files
    # End /etc/nsswitch.conf
    EOF

        tar -xf ./tzdata2024a.tar.gz

        ZONEINFO=/usr/share/zoneinfo
        mkdir -pv $ZONEINFO/{posix,right}

        for tz in etcetera southamerica northamerica europe africa antarctica \
          asia australasia backward; do

          zic -L /dev/null -d $ZONEINFO $tz
          zic -L /dev/null -d $ZONEINFO/posix $tz
          zic -L leapseconds -d $ZONEINFO/right $tz
        done

        cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
        zic -d $ZONEINFO -p America/New_York

        unset ZONEINFO

        ln -sfv /usr/share/zoneinfo/America/Los_Angeles /etc/localtime                  

        cat > /etc/ld.so.conf << "EOF"
    # Begin /etc/ld.so.conf
    /usr/local/lib
    /opt/lib
    EOF


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
    

