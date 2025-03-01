{ pkgs, lfsSrcs, lfsHashes, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "ss-vim-env";

    src = pkgs.fetchurl {
      url = lfsSrcs.vim;
      sha256 = lfsHashes.vim;
    };

    phases = [ "prepEnvironmentPhase" "unpackPhase" "configurePhase" "buildPhase" ];

    buildInputs = [ cc2 ];
    nativeBuildInputs = with pkgs; [
      gnutar
      xz
    ];

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
            "--hostname lfs-bwrap-vim"
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
            "--setenv MAKEFLAGS -j$(nproc)"
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
    set -e
    cd /tmp/src
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make -j$(nproc)
    # TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test &> ./vim-test.log

    make install

    ln -sv vim /usr/bin/vi
    for L in /usr/share/man/{,*/}man1/vim.1; do
        ln -sv vim.1 $(dirname $L)/vi.1
    done

    ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.0660

    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc
" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
set background=dark
endif
" End /etc/vimrc
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
