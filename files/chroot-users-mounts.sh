#!/bin/env bash

# Create /run/chroot if it doesn't exist
if [[ ! -d "/run/chroot" ]]; then
  mkdir /run/chroot
fi
 
# Run all the shell scripts in fstab.d
run-parts /etc/fstab.d
