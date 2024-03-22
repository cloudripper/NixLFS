{
  description = "NixLFS: Linux from Scratch.. from Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: let
    # 12.1 systemd list: "https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list";
    lfsSrcList = builtins.fromJSON (builtins.readFile ./lfs_sources.json);
    x86_pkgs = nixpkgs.legacyPackages.x86_64-linux;

    # Cross Compilation Toolchain
    binutilsStage =  import ./derivations/cross_toolchain/binutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; };
    gccStage1 =  import ./derivations/cross_toolchain/gcc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; customBinutils = binutilsStage; };
    linuxHeadersStage =  import ./derivations/cross_toolchain/linuxHeaders.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=gccStage1; };
    glibcStage =  import ./derivations/cross_toolchain/glibc.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=linuxHeadersStage; };
    libstdcppStage =  import ./derivations/cross_toolchain/libstdcpp.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=glibcStage; };

    # Cross compilation temp tools
    m4Stage = import ./derivations/temp_tools/m4.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=libstdcppStage; };
    ncursesStage = import ./derivations/temp_tools/ncurses.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=m4Stage; };
    bashStage = import ./derivations/temp_tools/bash.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=ncursesStage; };
    coreutilsStage = import ./derivations/temp_tools/coreutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=bashStage; };
    diffutilsStage = import ./derivations/temp_tools/diffutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=coreutilsStage; };
    fileStage = import ./derivations/temp_tools/file.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=diffutilsStage; };
    findutilsStage = import ./derivations/temp_tools/findutils.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=fileStage; };
    gawkStage = import ./derivations/temp_tools/gawk.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=findutilsStage; };
    grepStage = import ./derivations/temp_tools/grep.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=gawkStage; };
    gzipStage = import ./derivations/temp_tools/gzip.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=grepStage; };
    makeStage = import ./derivations/temp_tools/make.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=gzipStage; };
    patchStage = import ./derivations/temp_tools/patch.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=makeStage; };
    sedStage = import ./derivations/temp_tools/sed.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=patchStage; };
    tarStage = import ./derivations/temp_tools/tar.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=sedStage; };
    xzStage = import ./derivations/temp_tools/xz.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=tarStage; };
    binutils2Stage = import ./derivations/temp_tools/binutils2.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=xzStage; };
    gcc2Stage = import ./derivations/temp_tools/gcc2.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc1=binutils2Stage; };
    
    fhsPrep = import ./derivations/fhs/fhsprep.nix { pkgs = x86_pkgs; cc2=gcc2Stage; };
    fhsStage = import ./derivations/fhs.nix { pkgs = x86_pkgs; cc2=fhsPrep; };
    fhsBuildStage = import ./derivations/fhs/fhsbuild.nix { pkgs = x86_pkgs; cc2=gcc2Stage; };
    fhsGetTextStage = import ./derivations/fhs/fhsgettext.nix { pkgs = x86_pkgs; lfsSrcs = lfsSrcList; cc2=fhsBuildStage; };

    
  in {
      packages.x86_64-linux.crossToolchain = {
        default = libstdcppStage; 
        libstdcpp = libstdcppStage;
        glibc = glibcStage;
        linuxHeaders = linuxHeadersStage;
        gcc = gccStage1;
        binutils = binutilsStage;
      };

      packages.x86_64-linux.crossTempTools = { 
        default = ncursesStage;
        m4 = m4Stage;
        ncurses = ncursesStage; 
        bash = bashStage;
        coreutils = coreutilsStage;
        diffutils = diffutilsStage;
        file = fileStage;
        findutils = findutilsStage;
        gawk = gawkStage;
        grep = grepStage;
        gzip  = gzipStage;
        make = makeStage;
        patch = patchStage;
        sed = sedStage;
        tar = tarStage;
        xz = xzStage;
        binutils2 = binutils2Stage;
        gcc2 = gcc2Stage;
      };

      packages.x86_64-linux.fhs= {
        default = fhsGetTextStage; 
        build = fhsBuildStage;
        gettext = fhsGetTextStage;
        env = fhsPrep;
      };


      packages.x86_64-linux.default = fhsGetTextStage;
  };

}
