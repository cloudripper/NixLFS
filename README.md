# [WIP] - NixLFS: Linux from Scratch... from Nix
#### (Based on LFS 12.1 - systemd version)

## Overview
Building "Linux from Scratch" on a Nix-based, x86 system based on the [LFS project](www.linuxfromscratch.org)'s guidance. 

This project is a work-in-progress.

### Key differences in approach

The primary difference between NixLFS and traditional LFS is the build environment. LFS guidance is based on a traditional Linux environment, where you would need to take steps to protect your host system from the build process (for instance, utilizing chroot). By default, Nix provides sandboxing that isolates a build environment from system packages. In addition, LFS guidance is based on a FHS-compliant host environment - whereas NixOS utilizes a unique filesystem hierarchy (based largely on the Nix store).

The trade-offs:
- NixLFS build process is far more storage intensive as each stage is built independently as a dependency to the next stage and managed/stored in the nix store - leaving a sizeable output and storage footprint of greater than 12gb. 


### LFS Source List
LFS provides a [list of sources](https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list). This list was parsed into lfs_sources.json. 

### Checksums
LFS provides an md5sum list for the LFS packages, however md5 checksum is depricated in Nix fetch tools. SHA256 hashs manually applied for each package instead. 

### Modifications
- lfs_sources.json: source list for all dependencies of LFS. 
    - xz source was modified to an LFS mirror due to Github's xz ban.
- Kernel configurations are hard-coded in the ./derivations/sys_conf/linuxkernel.nix derivation and are performed using sed. A few additional BLFS-related kernel configurations added include:
    - bubblewrap
    - wireguard (no BLFS config)
    - wireshark
    - uefi
    - ALSA
    - iptables
    - networkmanager
    - wpa_supplicant
    - qemu

Perhaps this approach could be simplified in the future.


----

### Running NixLFS
_Flakes and nix-command experimental extras must be enabled in Nix._


The steps taken were adapted to a Nix contact from [LFS 12.1 - systemd guide](https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/LFS-BOOK-12.1-systemd-NOCHUNKS.html). 

#### Clone repo

```bash
git clone https://github.com/cloudripper/NixLFS.git && cd NixLFS
```

#### Setup partition/file system
See Part II of the LFS Guide to prepare/mount an LFS partition. If you are using NixOS, once the LFS partition is prepared, you can persist the mounting of the LFS partition by adding the following to your ```hardware-configuration.nix```:

```bash
    # /etc/nixos/hardware-configuration.nix
    fileSystems."/mnt/lfs" =
        {   device = "/dev/disk/by-uuid/<partition UUID>";
            fsType = "ext4";
        };
```

#### Build to /mnt/lfs
```bash
sudo ./lfs_script.sh --setup-env
```

This script runs four things:
1. It will run the full build, which on an 8-core processor will take around 5 hours. 
2. After building, the final output will be copied to /mnt/lfs
3. Permissions corrections will be applied in /mnt/lfs chroot
4. Shadow configuration will be applied in chroot

After build/copy/setup to /mnt/lfs, you can enter LFS partition chroot with:

```bash 
sudo ./lfs_chroot.sh --enter
```

#### Booting into LFS
If you are using Grub in NixOS, if useOSProber is set to true, Grub should automatically find the LFS OS. This can be enabled by adding ```boot.loader.grub.useOSProber =true;``` to your ```configuration.nix```.


#### Run build stages individually:

In order to manually run the build process, use the _nix build_ command

LFS chapter sections are broken up into individual derivative stages. These can be found in the derivations directory.
- Chapter 5 ("crossToolchain") stages are defined under cross_toolchain, these stages (and all preceding stages) are built by calling: ```nix build .#crossToolchain.<stage>```
- Chapter 6 ("crossTempTools") under temp_tools, these stages (and all preceding stages) are built by calling: ```nix build .#crossTempTools.<stage>```
- Chapter 7 ("fhs") is under fhs, these stages (and all preceding stages) are built by calling: ```nix build .#fhs.<stage>```
- Chapter 8 ("ss") is under sys_software, these stages (and all preceding stages) are built by calling: ```nix build .#ss.<stage>```
- Chapter 9 and Chapter 10 ("sysconf") stages are under sys_conf, these stages (and all preceding stages) are built by calling: ```nix build .#sysconf.<stage>```


```bash
# To build the entire LFS
nix build .#

# To build to a specific chapter/stage: nix build .#<chapter>.<stage>
# for example, to build the enter cross toolchain described in chapter 5 and get the path to the output, run
nix build .#crossToolchain.default --print-out-paths

# To build all stages up to and including the GCC2 build (in chapter 8) and get the path:
nix build .#ss.gcc --print-out-paths

# See flake.nix for more details.
```

#### Entering the dev environment for a stage

If you need to debug along the way, the development environment for a derivation can be entered by running:
```bash
nix develop .#<chapter>.<stage>
```



