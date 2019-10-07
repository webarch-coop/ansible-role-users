#!/usr/bin/env bash

# Create /run/chroot if it doesn't exist
if [[ ! -d "/run/chroot" ]]; then
  mkdir /run/chroot
fi

# Restart rsyslog
service rsyslog try-restart && service rsyslog restart
 
# Run all the shell scripts in fstab.d
run-parts /etc/fstab.d
