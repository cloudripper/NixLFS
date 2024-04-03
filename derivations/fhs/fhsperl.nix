{ pkgs, lfsSrcs, cc2 }:
let
  stdenvNoCC = pkgs.stdenvNoCC;

  fhsEnv = stdenvNoCC.mkDerivation {
    name = "fhs-perl-env";

    nativeBuildInputs = with pkgs; [
      cmake
      zlib
      bison
      coreutils
      findutils
      strace
      file
    ];


    src = builtins.fetchTarball {
      url = lfsSrcs.perl;
      sha256 = "1ddz3rqimsrlhzp786hg0z9yldj2866mckbkkgz0181yasdivwad";
    };

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

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
      export SRC=$PWD

      # Output directory
      mkdir $out
      # src folder
      mkdir -pv $LFS/tmp/src

      cp -rpv $SRC/* $LFS/tmp/src
      cp -rpv $SRC/.* $LFS/tmp/src    
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
              "--dir /tmp/out"
              "--bind $LFS/lib /lib"
              "--bind $LFS/lib /lib64"
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
      # eval "$configurePhase"
      # eval "$buildPhase"
      echo -e "\033[36mNix Develop -> $name: Loaded.\033[0m"
      echo -e "\033[36mNix Develop -> Current directory: $(pwd)\033[0m"
    '';
  };

  setupEnvScript = ''  
    cd /tmp/src
    
    sh Configure -des \
      -Dprefix=/usr \
      -Dvendorprefix=/usr \
      -Duseshrplib \
      -Dprivlib=/usr/lib/perl5/5.38/core_perl \
      -Darchlib=/usr/lib/perl5/5.38/core_perl \
      -Dsitelib=/usr/lib/perl5/5.38/site_perl \
      -Dsitearch=/usr/lib/perl5/5.38/site_perl \
      -Dvendorlib=/usr/lib/perl5/5.38/vendor_perl \
      -Dvendorarch=/usr/lib/perl5/5.38/vendor_perl \
      -Dcc=gcc \
      || exit 1    
    # cp -pvr ./ $OUT/home
    # exit 0
    LDLOADLIBS=-lc make || exit 1
    make install || exit 1
    
    mkdir $OUT/{usr,opt,srv,tmp,boot,home,sbin,root,etc,lib,var,bin,tools,media}
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
    cp -pvr /tools/* $OUT/tools
    cp -pvr /media/* $OUT/media
  '';
in
fhsEnv
    

