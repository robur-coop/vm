#!/bin/sh

set -xe

# Create _vm system user
useradd -r _vm || true

# Create directories
mkdir -p /etc/vm/vm.d
mkdir -p /etc/vm/vm.d/by-name
mkdir -p /var/lib/vm/chroot

# Install configuration
cp config.sh.dist /etc/vm/config.sh

# Create Thin Data, Meta LVs
lvcreate -n vmpool0 -L 24G tock-vg
lvcreate -n vmpool0meta -L 128m tock-vg

# Create Thin Pool LV
lvconvert --type thin-pool --poolmetadata tock-vg/vmpool0meta tock-vg/vmpool0

