{
  description = "NixLFS: Linux from Scratch.. from Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/f091af045dff8347d66d186a62d42aceff159456";
    unstable.url = "github:NixOS/nixpkgs/d8fe5e6c92d0d190646fb9f1056741a229980089";
  };

  outputs = { self, nixpkgs, unstable }:
    let
      # 12.1 systemd list: "https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list";
      lfsSrcList = builtins.fromJSON (builtins.readFile ./lfs_sources.json);
      x86_pkgs = nixpkgs.legacyPackages.x86_64-linux;
      unstable_x86_pkgs = unstable.legacyPackages.x86_64-linux;

      # Cross Compilation Toolchain
      binutilsStage = import ./derivations/cross_toolchain/binutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; };
      gccStage1 = import ./derivations/cross_toolchain/gcc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; customBinutils = binutilsStage; };
      linuxHeadersStage = import ./derivations/cross_toolchain/linuxHeaders.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = gccStage1; };
      glibcStage = import ./derivations/cross_toolchain/glibc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = linuxHeadersStage; };
      libstdcppStage = import ./derivations/cross_toolchain/libstdcpp.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = glibcStage; };

      # Cross compilation temp tools
      m4Stage = import ./derivations/temp_tools/m4.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = libstdcppStage; };
      ncursesStage = import ./derivations/temp_tools/ncurses.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = m4Stage; };
      bashStage = import ./derivations/temp_tools/bash.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = ncursesStage; };
      coreutilsStage = import ./derivations/temp_tools/coreutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = bashStage; };
      diffutilsStage = import ./derivations/temp_tools/diffutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = coreutilsStage; };
      fileStage = import ./derivations/temp_tools/file.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = diffutilsStage; };
      findutilsStage = import ./derivations/temp_tools/findutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = fileStage; };
      gawkStage = import ./derivations/temp_tools/gawk.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = findutilsStage; };
      grepStage = import ./derivations/temp_tools/grep.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = gawkStage; };
      gzipStage = import ./derivations/temp_tools/gzip.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = grepStage; };
      makeStage = import ./derivations/temp_tools/make.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = gzipStage; };
      patchStage = import ./derivations/temp_tools/patch.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = makeStage; };
      sedStage = import ./derivations/temp_tools/sed.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = patchStage; };
      tarStage = import ./derivations/temp_tools/tar.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = sedStage; };
      xzStage = import ./derivations/temp_tools/xz.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = tarStage; };
      binutils2Stage = import ./derivations/temp_tools/binutils2.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = xzStage; };
      gcc2Stage = import ./derivations/temp_tools/gcc2.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1 = binutils2Stage; };

      # FHS-compliant environment builds
      fhsPrep = import ./derivations/fhs/fhsprep.nix { pkgs = x86_pkgs; cc2 = gcc2Stage; };
      fhsBuildStage = import ./derivations/fhs/fhsbuild.nix { pkgs = x86_pkgs; cc2 = gcc2Stage; };
      fhsGetTextStage = import ./derivations/fhs/fhsgettext.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsBuildStage; };
      fhsBisonStage = import ./derivations/fhs/fhsbison.nix {
        pkgs = x86_pkgs;
        lfsSrcs = lfsSrcList;
        cc2 = fhsGetTextStage;
      };
      fhsPerlStage = import ./derivations/fhs/fhsperl.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsBisonStage; };
      fhsPythonStage = import ./derivations/fhs/fhspython.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsPerlStage; lib = nixpkgs.lib; };
      fhsTexinfoStage = import ./derivations/fhs/fhstexinfo.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsPythonStage; lib = nixpkgs.lib; };
      fhsUtilLinuxStage = import ./derivations/fhs/fhsutillinux.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsTexinfoStage; lib = nixpkgs.lib; };
      fhsCleanupStage = import ./derivations/fhs/fhscleanup.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsUtilLinuxStage; lib = nixpkgs.lib; };
      fhsTest = import ./derivations/fhs/fhstext.nix {
        pkgs = x86_pkgs;
        fhsEnv = fhsUtilLinuxStage;
      };

      # System software
      ssManpagesStage = import ./derivations/sys_software/ssmanpages.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = fhsUtilLinuxStage; lib = nixpkgs.lib; };
      ssIanaStage = import ./derivations/sys_software/ssianaetc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssManpagesStage; lib = nixpkgs.lib; };
      ssGlibcStage = import ./derivations/sys_software/ssglibc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssIanaStage; lib = nixpkgs.lib; };
      ssGlibcTimeStage = import ./derivations/sys_software/ssglibctime.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGlibcStage; lib = nixpkgs.lib; };
      ssZlibStage = import ./derivations/sys_software/sszlib.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGlibcTimeStage; lib = nixpkgs.lib; };
      ssBzip2Stage = import ./derivations/sys_software/ssbzip2.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssZlibStage; lib = nixpkgs.lib; };
      ssXzStage = import ./derivations/sys_software/ssxz.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssBzip2Stage; lib = nixpkgs.lib; };
      ssZstdStage = import ./derivations/sys_software/sszstd.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssXzStage; lib = nixpkgs.lib; };
      ssFileStage = import ./derivations/sys_software/ssfile.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssZstdStage; lib = nixpkgs.lib; };
      ssReadlineStage = import ./derivations/sys_software/ssreadline.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssFileStage; lib = nixpkgs.lib; };
      ssM4Stage = import ./derivations/sys_software/ssm4.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssReadlineStage; lib = nixpkgs.lib; };
      ssBcStage = import ./derivations/sys_software/ssbc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssM4Stage; lib = nixpkgs.lib; };
      ssFlexStage = import ./derivations/sys_software/ssflex.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssBcStage; lib = nixpkgs.lib; };
      ssTclStage = import ./derivations/sys_software/sstcl.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssFlexStage; lib = nixpkgs.lib; };
      ssExpectStage = import ./derivations/sys_software/ssexpect.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssTclStage; lib = nixpkgs.lib; };
      ssDejagnuStage = import ./derivations/sys_software/ssdejagnu.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssExpectStage; lib = nixpkgs.lib; };
      ssPkgconfStage = import ./derivations/sys_software/sspkgconf.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssDejagnuStage; lib = nixpkgs.lib; };
      ssGmpStage = import ./derivations/sys_software/ssgmp.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssPkgconfStage; lib = nixpkgs.lib; };
      ssMpfrStage = import ./derivations/sys_software/ssmpfr.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGmpStage; lib = nixpkgs.lib; };
      ssMpcStage = import ./derivations/sys_software/ssmpc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMpfrStage; lib = nixpkgs.lib; };
      ssAttrStage = import ./derivations/sys_software/ssattr.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMpcStage; lib = nixpkgs.lib; };
      ssAclStage = import ./derivations/sys_software/ssacl.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssAttrStage; lib = nixpkgs.lib; };
      ssLibcapStage = import ./derivations/sys_software/sslibcap.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssAclStage; lib = nixpkgs.lib; };
      ssLibxcryptStage = import ./derivations/sys_software/sslibxcrypt.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibcapStage; lib = nixpkgs.lib; };
      ssShadowStage = import ./derivations/sys_software/ssshadow.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibxcryptStage; lib = nixpkgs.lib; };
      ssGccStage = import ./derivations/sys_software/ssgcc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssShadowStage; lib = nixpkgs.lib; };
      ssNcursesStage = import ./derivations/sys_software/ssncurses.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGccStage; lib = nixpkgs.lib; };
      ssSedStage = import ./derivations/sys_software/sssed.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssNcursesStage; lib = nixpkgs.lib; };
      ssPsmiscStage = import ./derivations/sys_software/sspsmisc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssSedStage; lib = nixpkgs.lib; };
      ssGettextStage = import ./derivations/sys_software/ssgettext.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssPsmiscStage; lib = nixpkgs.lib; };
      ssBisonStage = import ./derivations/sys_software/ssbison.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGettextStage; lib = nixpkgs.lib; };
      ssGrepStage = import ./derivations/sys_software/ssgrep.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssBisonStage; lib = nixpkgs.lib; };
      ssBashStage = import ./derivations/sys_software/ssbash.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGrepStage; lib = nixpkgs.lib; };
      ssLibtoolStage = import ./derivations/sys_software/sslibtool.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssBashStage; lib = nixpkgs.lib; };
      ssGdbmStage = import ./derivations/sys_software/ssgdbm.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibtoolStage; lib = nixpkgs.lib; };
      ssGperfStage = import ./derivations/sys_software/ssgperf.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGdbmStage; lib = nixpkgs.lib; };
      ssExpatStage = import ./derivations/sys_software/ssexpat.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGperfStage; lib = nixpkgs.lib; };
      ssInetutilsStage = import ./derivations/sys_software/ssinetutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssExpatStage; lib = nixpkgs.lib; };
      ssLessStage = import ./derivations/sys_software/ssless.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssInetutilsStage; lib = nixpkgs.lib; };
      ssPerlStage = import ./derivations/sys_software/ssperl.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLessStage; lib = nixpkgs.lib; };
      ssXmlparserStage = import ./derivations/sys_software/ssxmlparser.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssPerlStage; lib = nixpkgs.lib; };
      ssIntltoolStage = import ./derivations/sys_software/ssintltool.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssXmlparserStage; lib = nixpkgs.lib; };
      ssAutoconfStage = import ./derivations/sys_software/ssautoconf.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssIntltoolStage; lib = nixpkgs.lib; };
      ssAutomakeStage = import ./derivations/sys_software/ssautomake.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssAutoconfStage; lib = nixpkgs.lib; };
      ssOpensslStage = import ./derivations/sys_software/ssopenssl.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssAutomakeStage; lib = nixpkgs.lib; };
      ssKmodStage = import ./derivations/sys_software/sskmod.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssOpensslStage; lib = nixpkgs.lib; };
      ssLibelfStage = import ./derivations/sys_software/sslibelf.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssKmodStage; lib = nixpkgs.lib; };
      ssLibffiStage = import ./derivations/sys_software/sslibffi.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibelfStage; lib = nixpkgs.lib; };
      ssPythonStage = import ./derivations/sys_software/sspython.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibffiStage; lib = nixpkgs.lib; };
      ssFlitcoreStage = import ./derivations/sys_software/ssflitcore.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssPythonStage; lib = nixpkgs.lib; };
      ssWheelStage = import ./derivations/sys_software/sswheel.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssFlitcoreStage; lib = nixpkgs.lib; };
      ssSetuptoolsStage = import ./derivations/sys_software/sssetuptools.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssWheelStage; lib = nixpkgs.lib; };
      ssNinjaStage = import ./derivations/sys_software/ssninja.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssSetuptoolsStage; lib = nixpkgs.lib; };
      ssMesonStage = import ./derivations/sys_software/ssmeson.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssNinjaStage; lib = nixpkgs.lib; };
      ssCoreutilsStage = import ./derivations/sys_software/sscoreutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMesonStage; lib = nixpkgs.lib; };
      ssCheckStage = import ./derivations/sys_software/sscheck.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssCoreutilsStage; lib = nixpkgs.lib; };
      ssDiffutilsStage = import ./derivations/sys_software/ssdiffutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssCheckStage; lib = nixpkgs.lib; };
      ssGawkStage = import ./derivations/sys_software/ssgawk.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssDiffutilsStage; lib = nixpkgs.lib; };
      ssFindutilsStage = import ./derivations/sys_software/ssfindutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGawkStage; lib = nixpkgs.lib; };
      ssGroffStage = import ./derivations/sys_software/ssgroff.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssFindutilsStage; lib = nixpkgs.lib; };
      ssGrubStage = import ./derivations/sys_software/ssgrub.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGroffStage; lib = nixpkgs.lib; };
      ssOprouteStage = import ./derivations/sys_software/ssoproute.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssGrubStage; lib = nixpkgs.lib; };
      ssKbdStage = import ./derivations/sys_software/sskbd.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssOprouteStage; lib = nixpkgs.lib; };
      ssLibpipelineStage = import ./derivations/sys_software/sslibpipeline.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssKbdStage; lib = nixpkgs.lib; };
      ssMakeStage = import ./derivations/sys_software/ssmake.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssLibpipelineStage; lib = nixpkgs.lib; };
      ssPatchStage = import ./derivations/sys_software/sspatch.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMakeStage; lib = nixpkgs.lib; };
      ssTarStage = import ./derivations/sys_software/sstar.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssPatchStage; lib = nixpkgs.lib; };
      ssTexinfoStage = import ./derivations/sys_software/sstexinfo.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssTarStage; lib = nixpkgs.lib; };
      ssVimStage = import ./derivations/sys_software/ssvim.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssTexinfoStage; lib = nixpkgs.lib; };
      ssMarkupsafeStage = import ./derivations/sys_software/ssmarkupsafe.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssVimStage; lib = nixpkgs.lib; };
      ssJinjaStage = import ./derivations/sys_software/ssjinja.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMarkupsafeStage; lib = nixpkgs.lib; };
      ssSystemdStage = import ./derivations/sys_software/sssystemd.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssJinjaStage; lib = nixpkgs.lib; };
      ssDbusStage = import ./derivations/sys_software/ssdbus.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssSystemdStage; lib = nixpkgs.lib; };
      ssMandbStage = import ./derivations/sys_software/ssmandb.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssDbusStage; lib = nixpkgs.lib; };
      ssProcpsStage = import ./derivations/sys_software/ssprocps.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssMandbStage; lib = nixpkgs.lib; };
      ssUtillinuxStage = import ./derivations/sys_software/ssutillinux.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssProcpsStage; lib = nixpkgs.lib; };
      ssE2FsprogsiStage = import ./derivations/sys_software/sse2fsprogsi.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2 = ssUtillinuxStage; lib = nixpkgs.lib; };


    in
    {
      packages.x86_64-linux.crossToolchain = {
        default = libstdcppStage;
        libstdcpp = libstdcppStage;
        glibc = glibcStage;
        linuxHeaders = linuxHeadersStage;
        gcc = gccStage1;
        binutils = binutilsStage;
      };

      packages.x86_64-linux.crossTempTools = {
        default = gcc2Stage;
        m4 = m4Stage;
        ncurses = ncursesStage;
        bash = bashStage;
        coreutils = coreutilsStage;
        diffutils = diffutilsStage;
        file = fileStage;
        findutils = findutilsStage;
        gawk = gawkStage;
        grep = grepStage;
        gzip = gzipStage;
        make = makeStage;
        patch = patchStage;
        sed = sedStage;
        tar = tarStage;
        xz = xzStage;
        binutils2 = binutils2Stage;
        gcc2 = gcc2Stage;
      };

      packages.x86_64-linux.fhs = {
        default = fhsUtilLinuxStage;
        build = fhsBuildStage;
        gettext = fhsGetTextStage;
        bison = fhsBisonStage;
        perl = fhsPerlStage;
        python = fhsPythonStage;
        texinfo = fhsTexinfoStage;
        utillinux = fhsUtilLinuxStage;
        cleanup = fhsCleanupStage;
        test = fhsTest;
        env = fhsPrep;
      };

      packages.x86_64-linux.ss = {
        default = ssE2FsprogsiStage;
        manpages = ssManpagesStage;
        iana = ssIanaStage;
        glibc = ssGlibcStage;
        glibctime = ssGlibcTimeStage;
        zlib = ssZlibStage;
        bzip2 = ssBzip2Stage;
        xz = ssXzStage;
        zstd = ssZstdStage;
        file = ssFileStage;
        readline = ssReadlineStage;
        m4 = ssM4Stage;
        bc = ssBcStage;
        flex = ssFlexStage;
        tcl = ssTclStage;
        expect = ssExpectStage;
        dejagnu = ssDejagnuStage;
        pkgconf = ssPkgconfStage;
        gmp = ssGmpStage;
        mpfr = ssMpfrStage;
        mpc = ssMpcStage;
        attr = ssAttrStage;
        acl = ssAclStage;
        libcap = ssLibcapStage;
        libxcrypt = ssLibxcryptStage;
        shadow = ssShadowStage;
        gcc = ssGccStage;
        ncurses = ssNcursesStage;
        sed = ssSedStage;
        psmisc = ssPsmiscStage;
        gettext = ssGettextStage;
        bison = ssBisonStage;
        grep = ssGrepStage;
        bash = ssBashStage;
        libtool = ssLibtoolStage;
        gdbm = ssGdbmStage;
        gperf = ssGperfStage;
        expat = ssExpatStage;
        inetutils = ssInetutilsStage;
        less = ssLessStage;
        perl = ssPerlStage;
        xmlparser = ssXmlparserStage;
        intltool = ssIntltoolStage;
        autoconf = ssAutoconfStage;
        automake = ssAutomakeStage;
        openssl = ssOpensslStage;
        kmod = ssKmodStage;
        libelf = ssLibelfStage;
        libffi = ssLibffiStage;
        python = ssPythonStage;
        flitcore = ssFlitcoreStage;
        wheel = ssWheelStage;
        setuptools = ssSetuptoolsStage;
        ninja = ssNinjaStage;
        meson = ssMesonStage;
        coreutils = ssCoreutilsStage;
        check = ssCheckStage;
        diffutils = ssDiffutilsStage;
        gawk = ssGawkStage;
        findutils = ssFindutilsStage;
        groff = ssGroffStage;
        grub = ssGrubStage;
        oproute = ssOprouteStage;
        kbd = ssKbdStage;
        libpipeline = ssLibpipelineStage;
        make = ssMakeStage;
        patch = ssPatchStage;
        tar = ssTarStage;
        texinfo = ssTexinfoStage;
        vim = ssVimStage;
        markupsafe = ssMarkupsafeStage;
        jinja = ssJinjaStage;
        systemd = ssSystemdStage;
        dbus = ssDbusStage;
        mandb = ssMandbStage;
        procps = ssProcpsStage;
        utillinux = ssUtillinuxStage;
        e2fsprogsi = ssE2FsprogsiStage;
      };


      packages.x86_64-linux.default = fhsUtilLinuxStage;
    };

}
