# [WIP] - NixLFS: Linux from Scratch... from Nix
#### Based on LFS 12.1 - systemd version

## Overview
This project builds "Linux from Scratch" (LFS) on a Nix-based, x86 system, following the [LFS project](https://www.linuxfromscratch.org)'s guidance. It's a work-in-progress adapting the LFS 12.1 (systemd version) for a Nix environment.

### Key Differences in Approach

Unlike traditional LFS, which relies on a standard Linux environment and often uses `chroot` to protect the host system during builds, NixLFS utilizes Nix's native sandboxing. This isolates the build environment completely from the host system's packages, leveraging NixOS's unique filesystem hierarchy centered around the Nix store.

**Trade-offs:**
- **Storage Intensity:** NixLFS is more storage-intensive, as it builds each stage independently as a dependency of the next. This results in a significant storage footprint, often exceeding 12GB.

### LFS Source List
LFS provides a [list of sources](https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list) needed for the build. We've converted this list into `lfs_sources.json`.

### Checksums
While LFS uses md5 checksums, Nix fetch tools use SHA256. We've applied SHA256 hashes manually for each package.

### Modifications
- **`lfs_sources.json`**: Modified to use an LFS mirror for the xz source due to Github's xz ban.
- **Kernel configurations**: Configurations are predefined in `./derivations/sys_conf/linuxkernel.nix` using `sed`. Additional configurations from BLFS include bubblewrap, WireGuard, Wireshark, UEFI, ALSA, iptables, NetworkManager, wpa_supplicant, and QEMU.

    Future efforts may simplify kernel configuration.

- **LFS Permissions**: Nix sandboxing prevents handling of most permissions modifications within the build environment. As a work around, wrappers are applied beginning from fhs/fhsbuild.nix. These wrappers log chmod/chgrp/chown calls during build of the LFS system. These logs were parsed after completion of the kernel build and select permissions are applied post-build as apart of the bash script used to orchestra the LFS build (see below).

## Running NixLFS
**Prerequisites:** Enable Flakes and nix-command experimental features in Nix.

### Setup
Clone the repository and prepare the filesystem:
```bash
git clone https://github.com/cloudripper/NixLFS.git
cd NixLFS
```
Prepare and mount an LFS partition as described in Part II of the LFS Guide. On NixOS, add the following to your `hardware-configuration.nix` to persist the mount:
```nix
# /etc/nixos/hardware-configuration.nix
fileSystems."/mnt/lfs" = {
    device = "/dev/disk/by-uuid/<partition UUID>";
    fsType = "ext4";
};
```

### Build Process
Run the build script to build LFS and populate/set up the LFS environment in /mnt/lfs partition:
```bash
sudo ./lfs_script.sh --setup-env
```
This script:
1. Completes the full build (approximately 5 hours on an 8-core processor).
2. Copies the final output to `/mnt/lfs`.
3. Applies permission corrections within the `/mnt/lfs` chroot.
4. Configures shadow settings within the chroot.

Enter the LFS chroot:
```bash 
sudo ./lfs_chroot.sh --enter
```

### Booting into LFS
If using Grub on NixOS with `useOSProber` set to true, Grub should automatically detect the LFS OS. Enable this by adding to your `configuration.nix`:
```nix
boot.loader.grub.useOSProber = true;
```

### Manual Build Process
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