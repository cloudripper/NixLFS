#!/usr/bin/env bash

set -e

LFS=/mnt/lfs

# Function definitions
build() {
  echo "Build output location: $(nix build $PWD# --print-out-paths)"
}

copy_build_to_lfs() {
  if ! mountpoint -q "$LFS"; then
    echo "Mount Error: No partition is mounted at $LFS."
    exit 1
  fi


  cp -rpv $(nix build $PWD# --print-out-paths)/* "$LFS"

  # ELF interpreter is set to /lib64. If LFS chroot doesn't work, make sure $LFS/lib64
  # is present and correctly symlinked to usr/lib
  pushd $LFS
  if [ ! -L lib64 ]; then
    sudo ln -sv usr/lib lib64
  fi
  popd
}

setup_shadow() {
    echo "Setting up LFS..."
    echo "Enter new LFS root password (this will be used when booting into LFS):"
    read -s password

    echo 'pwconv
    grpconv
    mkdir -p /etc/default
    useradd -D --gid 999
    echo 'root:$password' | chpasswd' > $LFS/tmp/shadow_conf.sh

    sudo chroot "$LFS" /usr/bin/env -i \
                      HOME=/root \
                      TERM="$TERM" \
                      PS1='(nixlfs chroot) \u:\w\$ ' \
                      PATH=/usr/bin:/usr/sbin \
                      /bin/bash /tmp/shadow_conf.sh
}

enter_chroot() {
  sudo chroot "$LFS" /usr/bin/env -i \
                    HOME=/root \
                    TERM="$TERM" \
                    PS1='(nixlfs chroot) \u:\w\$ ' \
                    PATH=/usr/bin:/usr/sbin \
                    /bin/bash --login
}

enter_qemu() {
    if ! mountpoint -q "$LFS"; then
      echo "Mount Error: No partition is mounted at $LFS."
      exit 1
    fi

    KERNEL=$(ls $LFS/boot/vmlinuz*)

    if [ ! -f "$KERNEL" ]; then
      echo "Error: LFS kernel is missing."
      exit 1
    fi

    PARTITION="$(findmnt -no SOURCE "$LFS")"
    PARENT_DISK="$(lsblk -no PKNAME "$PARTITION")"
    UNDERLYING_DRIVE="/dev/$PARENT_DISK"

    sudo qemu-system-x86_64 \
        -kernel $KERNEL \
        -append "root=/dev/vda4 ro console=ttyS0" \
        -drive file=$UNDERLYING_DRIVE,format=raw,if=virtio \
        -m 2G -enable-kvm -serial mon:stdio -nographic
}


post_build_permissions() {

# Run script to set all permissions as defined
sudo chroot "$LFS" /usr/bin/env -i \
                   HOME=/root \
                   TERM="$TERM" \
                   PS1='(nixlfs chroot) \u:\w\$ ' \
                   PATH=/usr/bin:/usr/sbin \
                   MAKEFLAGS="-j$(nproc)" \
                   TESTSUITEFLAGS="-j$(nproc)" \
                   /bin/bash <<EOF
# Helper: recursively set directories to DMODE and files to FMODE.
set_permissions_recursive() {
    local target="$1"
    local dmode="$2"
    local fmode="$3"
    if [ -d "$target" ]; then
    echo "Setting directories in $target to $dmode and files to $fmode"
    find "$target" -type d -exec chmod "$dmode" {} \;
    find "$target" -type f -exec chmod "$fmode" {} \;
    fi
}

# For documentation and similar static content, FHS typically uses:
# Directories: 755, Files: 644

set_permissions_recursive /usr/share/man 755 644
set_permissions_recursive /usr/share/doc 755 644
set_permissions_recursive /usr/share/info 755 644
set_permissions_recursive /usr/share/vim 755 644
echo "# (chroot) Recursive permissions set"

# Set system directories according to FHS 3.0 and security guidelines.
chmod 755 /
chmod 755 /bin
chmod 755 /boot
chmod 755 /etc
chmod 711 /home
chmod 755 /lib
chmod 755 /lib64
chmod 755 /media
chmod 755 /opt
chmod 700 /root
chmod 755 /sbin
chmod 755 /srv
chmod 755 /usr
chmod 755 /var
chmod 1777 /tmp
chmod 1777 /var/tmp
echo "# (chroot) Root permissions set"

# Critical executables that need elevated privileges
chmod 4755 /bin/mount /bin/umount
EOF

}

permissions() {
    echo "Setting permissions..."
    post_build_permissions
    echo "Permissions set."
}

if [ ! -d "$LFS" ]; then
  echo "LFS directory, "$LFS", does not exist."
  exit 1
fi

if [[ $# -gt 0 ]]; then
  case $1 in
    --test)
      test_fun
      ;;
    --build)
      build
      ;;
    --setup-env)
      copy_build_to_lfs
      permissions
      setup_shadow
      ;;
    --enter-chroot)
      enter_chroot
      ;;
    --enter-qemu)
      enter_qemu
      ;;
    --set-perms)
      permissions
      ;;
    --build-enter)
      copy_build_to_lfs
      permissions
      setup_shadow
      enter_qemu
      ;;
    *)
      echo "Invalid arg: try --build-enter (to run full build and enter qemu), --build (build only and output nix store path) --setup-env (build, copy to /mnt/lfs, correct permissions, apply shadow conf), --enter-qemu (boot build via QEMU), --enter-chroot (enter chroot only) as arguments"
      exit 1
      ;;
  esac
  exit 0
fi
exit 1
