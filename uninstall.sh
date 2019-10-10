#!/bin/sh

set -xe

# Remove Thin Pool LV
lvremove tock-vg/vmpool0

# Remove directories
rm -rf /etc/vm
rm -rf /var/lib/vm/chroot

# Remove _vm system user
userdel _vm

