#!/bin/bash

chroot_users_dir=/etc/fstab.d
# runs all the shell scripts in chroot_users_dir 
run-parts ${chroot_users_dir}
