{ pkgs, lfsSrcs, cc2, lib }:
let
  stdenv = pkgs.stdenv;

  fhsEnv = stdenv.mkDerivation {
    name = "linux-kernel-env";

    src = builtins.fetchTarball {
      url = lfsSrcs.linux;
      sha256 = "1rxxdryryqirrcyq6z39x0jl6fkprlk3xr5m3rz5br2jcxkra4sg";
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

      cp -rpv $SRC/.* $LFS/tmp/src
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

        make defconfig

        # Change Config
        for file in ./.config; do
          sed -i 's/CONFIG_WERROR=y/# CONFIG_WERROR is not set/g' $file
          sed -i 's/CONFIG_AUDIT=y/# CONFIG AUDIT is not set/g' $file
          sed -i 's/CONFIG_AUDITSYSCALL=y/# CONFIG_AUDITSYSCALL=y/g' $file
          sed -i 's/# CONFIG_PSI is not set/CONFIG_PSI=y/g' $file
          sed -i 's/# CONFIG_MEMCG is not set/CONFIG_MEMCG=y\nCONFIG_MEMCG_KMEM=y\nCONFIG_CGROUP_WRITEBACK=y/g' $file
          sed -i 's/# CONFIG_USER_NS is not set/CONFIG_USER_NS=y/g' $file
          sed -i 's/CONFIG_LD_ORPHAN_WARN_LEVEL="error"/CONFIG_LD_ORPHAN_WARN_LEVEL="warn"/g' $file
          sed -i 's/CONFIG_HAVE_PERF_EVENTS=y/CONFIG_HAVE_PERF_EVENTS=y\nCONFIG_GUEST_PERF_EVENTS=y/g' $file
          sed -i 's/# CONFIG_X86_X2APIC is not set/CONFIG_X86_X2APIC=y/g' $file
          sed -i 's/# CONFIG_GART_IOMMU is not set/# CONFIG_GART_IOMMU is not set\nCONFIG_BOOT_VESA_SUPPORT=y/g' $file
          sed -i 's/CONFIG_HAVE_KVM=y/CONFIG_HAVE_KVM=y\nCONFIG_HAVE_KVM_PFNCACHE=y\nCONFIG_HAVE_KVM_IRQCHIP=y\nCONFIG_HAVE_KVM_IRQFD=y\nCONFIG_HAVE_KVM_IRQ_ROUTING=y\nCONFIG_HAVE_KVM_DIRTY_RING=y\nCONFIG_HAVE_KVM_DIRTY_RING_TSO=y\nCONFIG_HAVE_KVM_DIRTY_RING_ACQ_REL=y\nCONFIG_HAVE_KVM_EVENTFD=y\nCONFIG_KVM_MMIO=y\nCONFIG_KVM_ASYNC_PF=y\nCONFIG_HAVE_KVM_MSI=y\nCONFIG_HAVE_KVM_CPU_RELAX_INTERCEPT=y\nCONFIG_KVM_VFIO=y\nCONFIG_KVM_GENERIC_DIRTYLOG_READ_PROTECT=y\nCONFIG_KVM_COMPAT=y\nCONFIG_HAVE_KVM_IRQ_BYPASS=y\nCONFIG_HAVE_KVM_NO_POLL=y\nCONFIG_KVM_XFER_TO_GUEST_WORK=y\nCONFIG_HAVE_KVM_PM_NOTIFIER=y\nCONFIG_KVM_GENERIC_HARDWARE_ENABLING=y/g' $file
          sed -i 's/# CONFIG_KVM is not set/CONFIG_KVM=y\nCONFIG_KVM_INTEL=y\n# CONFIG_KVM_AMD is not set\nCONFIG_KVM_SMM=y\n# CONFIG_KVM_XEN is not set\nCONFIG_KVM_MAX_NR_VCPUS=1024/g' $file
          sed -i 's/CONFIG_KRETPROBE_ON_RETHOOK=y/CONFIG_KRETPROBE_ON_RETHOOK=y\nCONFIG_USER_RETURN_NOTIFIER=y/g' $file
          sed -i 's/# CONFIG_PARTITION_ADVANCED is not set/CONFIG_PARTITION_ADVANCED=y\n# CONFIG_ACORN_PARTITION is not set\n# CONFIG_AIX_PARTITION is not set\n# CONFIG_OSF_PARTITION is not set\n# CONFIG_AMIGA_PARTITION is not set\n# CONFIG_ATARI_PARTITION is not set\n# CONFIG_MAC_PARTITION is not set/g' $file
          sed -i 's/CONFIG_MSDOS_PARTITION=y/CONFIG_MSDOS_PARTITION=y\n# CONFIG_BSD_DISKLABEL is not set\n# CONFIG_MINIX_SUBPARTITION is not set\n# CONFIG_SOLARIS_X86_PARTITION is not set\n# CONFIG_UNIXWARE_DISKLABEL is not set\n# CONFIG_LDM_PARTITION is not set\n# CONFIG_SGI_PARTITION is not set\n# CONFIG_ULTRIX_PARTITION is not set\n# CONFIG_SUN_PARTITION is not set\n# CONFIG_KARMA_PARTITION is not set/g' $file
          sed -i 's/CONFIG_EFI_PARTITION=y/CONFIG_EFI_PARTITION=y\n# CONFIG_SYSV68_PARTITION is not set\n# CONFIG_CMDLINE_PARTITION is not set/g' $file
          sed -i 's/CONFIG_ASN1=y/CONFIG_PREEMPT_NOTIFIERS=y\nCONFIG_ASN1=y/g' $file
          sed -i 's/CONFIG_NET=y/CONFIG_NET=y\nCONFIG_COMPAT_NETLINK_MESSAGES=y/g' $file
          sed -i 's/# CONFIG_NET_IPIP is not set/CONFIG_NET_IPIP=y/g' $file
          sed -i 's/# CONFIG_NET_IPGRE_DEMUX is not set/CONFIG_NET_IPGRE_DEMUX=y/g' $file
          sed -i 's/CONFIG_NET_IP_TUNNEL=y/CONFIG_NET_IP_TUNNEL=y\nCONFIG_NET_IPGRE=y/g' $file
          sed -i 's/# CONFIG_NET_IPVTI is not set/# CONFIG_NET_IPVTI is not set\nCONFIG_NET_UDP_TUNNEL=y/g' $file
          sed -i 's/# CONFIG_IPV6_ILA is not set/# CONFIG_IPV6_ILA is not set\nCONFIG_INET6_TUNNEL=y/g' $file
          sed -i 's/# CONFIG_IPV6_TUNNEL is not set/CONFIG_IPV6_TUNNEL=y\nCONFIG_IPV6_GRE=y/g' $file
          sed -i 's/# CONFIG_IPV6_MULTIPLE_TABLES is not set/CONFIG_IPV6_MULTIPLE_TABLES=y\n# CONFIG_IPV6_SUBTREES is not set/g' $file
          sed -i 's/# CONFIG_MPTCP is not set/CONFIG_MPTCP=y\nCONFIG_MPTCP_IPV6=y/g' $file
          sed -i 's/CONFIG_NETWORK_SECMARK=y/# CONFIG_NETWORK_SECMARK is not set/g' $file
          sed -i 's/# CONFIG_NETFILTER_ADVANCED is not set/CONFIG_NETFILTER_ADVANCED=y/g' $file
          sed -i 's/CONFIG_NF_LOG_SYSLOG=m/CONFIG_NF_LOG_SYSLOG=y/g' $file
          sed -i 's/CONFIG_NF_CONNTRACK_SECMARK=y/# CONFIG_NF_CONNTRACK_MARK is not set\n# CONFIG_NF_CONNTRACK_ZONES is not set/g' $file
          sed -i 's/# CONFIG_NF_CONNTRACK_LABELS is not set/# CONFIG_NF_CONNTRACK_LABELS is not set\nCONFIG_NF_CT_PROTO_DCCP=y\nCONFIG_NF_CT_PROTO_SCTP=y\nCONFIG_NF_CT_PROTO_UDPLITE=y\n# CONFIG_NF_CONNTRACK_AMANDA is not set/g' $file
          sed -i 's/CONFIG_NF_NAT_MASQUERADE=y//g' $file
          sed -i 's/CONFIG_NETFILTER_XT_MARK=m/# CONFIG_NETFILTER_XT_MARK is not set/g' $file
          sed -i 's/CONFIG_NETFILTER_XT_TARGET_CONNSECMARK=y/ /g' $file
          sed -i 's/CONFIG_NETFILTER_XT_TARGET_LOG=m/CONFIG_NETFILTER_XT_TARGET_LOG=y/g' $file
          sed -i 's/CONFIG_NETFILTER_XT_NAT=m/# CONFIG_NETFILTER_XT_NAT is not set/g' $file
          sed -i 's/CONFIG_NETFILTER_XT_TARGET_MASQUERADE=m/# CONFIG_NETFILTER_XT_TARGET_MASQUERADE is not set/g' $file
          sed -i 's/CONFIG_NETFILTER_XT_TARGET_SECMARK=y/# CONFIG_NETFILTER_XT_TARGET_SECMARK=y/g' $file
          sed -i 's/CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=m/# CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=m/g' $file
          sed -i 's/CONFIG_NF_LOG_ARP=m/# CONFIG_NF_LOG_ARP=m/g' $file
          sed -i 's/CONFIG_NF_LOG_IPV4=m/# CONFIG_NF_LOG_IPV4=m/g' $file
          sed -i 's/CONFIG_IP_NF_NAT=m/# CONFIG_IP_NF_NAT=m/g' $file
          sed -i 's/CONFIG_IP_NF_TARGET_MASQUERADE=m/# CONFIG_IP_NF_TARGET_MASQUERADE=m/g' $file
          sed -i 's/CONFIG_NF_LOG_IPV6=m/CONFIG_NF_LOG_IPV6=m/g' $file
          sed -i 's/# CONFIG_BRIDGE is not set/CONFIG_STP=y\nCONFIG_BRIDGE=y\nCONFIG_BRIDGE_IGMP_SNOOPING=y\n# CONFIG_BRIDGE_VLAN_FILTERING is not set\n# CONFIG_BRIDGE_MRP is not set\n# CONFIG_BRIDGE_CFM is not set/g' $file
          sed -i 's/# CONFIG_VLAN_8021Q is not set/CONFIG_VLAN_8021Q=y\n# CONFIG_VLAN_8021Q_GVRP is not set\n# CONFIG_VLAN_8021Q_MVRP is not set\nCONFIG_LLC=y/g' $file
          sed -i 's/# CONFIG_NET_SCH_SFQ is not set/CONFIG_NET_SCH_SFQ=y/g' $file
          sed -i 's/# CONFIG_NET_SCH_TBF is not set/CONFIG_NET_SCH_TBF=y/g' $file
          sed -i 's/# CONFIG_NET_SCH_FQ_CODEL is not set/CONFIG_NET_SCH_FQ_CODEL=y/g' $file
          sed -i 's/# CONFIG_NET_SCH_INGRESS is not set/CONFIG_NET_SCH_INGRESS=y/g' $file
          sed -i 's/# CONFIG_NET_L3_MASTER_DEV is not set/CONFIG_NET_L3_MASTER_DEV=y/g' $file
          sed -i 's/CONFIG_WIRELESS=y/CONFIG_WIRELESS=y\nCONFIG_WEXT_CORE=y\nCONFIG_WEXT_PROC=y/g' $file
          sed -i 's/# CONFIG_CFG80211_WEXT is not set/CONFIG_CFG80211_WEXT=y/g' $file
          sed -i 's/CONFIG_NET_SELFTESTS=y/CONFIG_NET_SELFTESTS=y\nCONFIG_PAGE_POOL=y/g' $file
          sed -i 's/# CONFIG_SYSFB_SIMPLEFB is not set/CONFIG_SYSFB=y\nCONFIG_SYSFB_SIMPLEFB=y/g' $file
          sed -i 's/# CONFIG_BLK_DEV_NVME is not set/CONFIG_NVME_CORE=y\nCONFIG_BLK_DEV_NVME=y\n# CONFIG_NVME_MULTIPATH is not set\n# CONFIG_NVME_VERBOSE_ERRORS is not set\n# CONFIG_NVME_HWMON is not set\n# CONFIG_NVME_HOST_AUTH is not set/g' $file
          sed -i 's/# CONFIG_DM_AUDIT is not set//g' $file
          sed -i 's/# CONFIG_BONDING is not set/CONFIG_BONDING=y/g' $file
          sed -i 's/# CONFIG_DUMMY is not set/CONFIG_DUMMY=y/g' $file
          sed -i 's/# CONFIG_WIREGUARD is not set/CONFIG_WIREGUARD=y\n# CONFIG_WIREGUARD_DEBUG is not set/g' $file
          sed -i 's/# CONFIG_NET_TEAM is not set/CONFIG_NET_TEAM=y/g' $file
          sed -i 's/# CONFIG_MACVLAN is not set/CONFIG_MACVLAN=y\nCONFIG_MACVTAP=y/g' $file
          sed -i 's/# CONFIG_IPVLAN is not set/CONFIG_IPVLAN_L3S=y\nCONFIG_IPVLAN=y/g' $file
          sed -i 's/# CONFIG_VXLAN is not set/CONFIG_VXLAN=y/g' $file
          sed -i 's/# CONFIG_TUN is not set/CONFIG_TUN=y\nCONFIG_TAP=y/g' $file
          sed -i 's/# CONFIG_VETH is not set/CONFIG_VETH=y\nCONFIG_NET_VRF=y/g' $file
          sed -i 's/# CONFIG_VT_HW_CONSOLE_BINDING is not set/CONFIG_VT_HW_CONSOLE_BINDING=y/g' $file
          sed -i 's/# CONFIG_DRM_FBDEV_EMULATION is not set/CONFIG_DRM_FBDEV_EMULATION=y\nCONFIG_DRM_FBDEV_OVERALLOC=100/g' $file
          sed -i 's/# CONFIG_DRM_SIMPLEDRM is not set/CONFIG_DRM_SIMPLEDRM=y/g' $file
          sed -i 's/# CONFIG_FB is not set/CONFIG_FB_CORE=y\n# CONFIG_FB_DEVICE is not set\nCONFIG_FB_CFB_FILLRECT=y\nCONFIG_FB_CFB_COPYAREA=y\nCONFIG_FB_CFB_IMAGEBLIT=y\nCONFIG_FB_SYS_FILLRECT=y\nCONFIG_FB_SYS_COPYAREA=y\nCONFIG_FB_SYS_IMAGEBLIT=y\nCONFIG_FB_SYS_FOPS=y\nCONFIG_FB_DEFERRED_IO=y\nCONFIG_FB_IOMEM_FOPS=y\nCONFIG_FB_IOMEM_HELPERS=y\nCONFIG_FB_SYSMEM_HELPERS=y\nCONFIG_FB_SYSMEM_HELPERS_DEFERRED=y/g' $file
          sed -i 's/CONFIG_DUMMY_CONSOLE_ROWS=25/CONFIG_DUMMY_CONSOLE_ROWS=25\nCONFIG_FRAMEBUFFER_CONSOLE=y\n# CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION is not set\nCONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y\n# CONFIG_FRAMEBUFFER_CONSOLE_ROTATION is not set/g' $file
          sed -i 's/# CONFIG_VFIO is not set/# CONFIG_VFIO is not set\nCONFIG_IRQ_BYPASS_MANAGER=y/g' $file
          sed -i 's/# CONFIG_IRQ_REMAP is not set/CONFIG_IRQ_REMAP=y/g' $file
          sed -i 's/CONFIG_LSM_MMAP_MIN_ADDR=65536//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX=y//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX_BOOTPARAM=y//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX_DEVELOP=y//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX_AVC_STATS=y//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX_SIDTAB_HASH_BITS=9//g' $file
          sed -i 's/CONFIG_SECURITY_SELINUX_SID2STR_CACHE_SIZE=256//g' $file
          sed -i 's/CONFIG_INTEGRITY_AUDIT=y//g' $file
          sed -i 's/CONFIG_DEFAULT_SECURITY_SELINUX=y//g' $file
          sed -i 's/# CONFIG_DEFAULT_SECURITY_DAC is not set/CONFIG_DEFAULT_SECURITY_DAC=y/g' $file
          sed -i 's/CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,selinux,smack,tomoyo,apparmor,bpf"/CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,bpf"/g' $file
          sed -i 's/# CONFIG_CRYPTO_CURVE25519_X86 is not set/CONFIG_CRYPTO_CURVE25519_X86=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_CHACHA20_X86_64 is not set/CONFIG_CRYPTO_CHACHA20_X86_64=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_BLAKE2S_X86 is not set/CONFIG_CRYPTO_BLAKE2S_X86=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_POLY1305_X86_64 is not set/CONFIG_CRYPTO_POLY1305_X86_64=y/g' $file
          sed -i 's/CONFIG_CRYPTO_LIB_GF128MUL=y/CONFIG_CRYPTO_LIB_GF128MUL=y\nCONFIG_CRYPTO_ARCH_HAVE_LIB_BLAKE2S=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_LIB_CHACHA is not set/CONFIG_CRYPTO_ARCH_HAVE_LIB_CHACHA=y\nCONFIG_CRYPTO_LIB_CHACHA_GENERIC=y\nCONFIG_CRYPTO_LIB_CHACHA=y\nCONFIG_CRYPTO_ARCH_HAVE_LIB_CURVE25519=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_LIB_CURVE25519 is not set/CONFIG_CRYPTO_LIB_CURVE25519_GENERIC=y\nCONFIG_CRYPTO_LIB_CURVE25519=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_LIB_POLY1305 is not set/CONFIG_CRYPTO_ARCH_HAVE_LIB_POLY1305=y\nCONFIG_CRYPTO_LIB_POLY1305_GENERIC=y/g' $file
          sed -i 's/# CONFIG_CRYPTO_LIB_CHACHA20POLY1305 is not set/CONFIG_CRYPTO_LIB_POLY1305=y\nCONFIG_CRYPTO_LIB_CHACHA20POLY1305=y/g' $file
          sed -i 's/# CONFIG_LIBCRC32C is not set/CONFIG_LIBCRC32C=y/g' $file
          sed -i 's/CONFIG_FONT_AUTOSELECT=y/CONFIG_FONT_8x8=y/g' $file
        done

        make 

        make modules_install 

        mkdir /boot

        cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.7.4-lfs-12.1-systemd

        cp -iv System.map /boot/System.map-6.7.4

        cp -iv .config /boot/config-6.7.4

        cp -r Documentation -T /usr/share/doc/linux-6.7.4

        install -v -m755 -d /etc/modprobe.d
    
        cat > /etc/modprobe.d/usb.conf << "EOF"
    # Begin /etc/modprobe.d/usb.conf
    install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
    install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true
    # End /etc/modprobe.d/usb.conf
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
          
    
