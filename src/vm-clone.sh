#!/bin/sh

#
# Clone an existing virtual machine
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="Clone an existing virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID

Creates a clone of the virtual machine specified by NAME or VMID.

The user-visible name of the cloned virtual machine will be set to:

    NAME-clone-SUFFIX

where NAME is the source virtual machine's name and SUFFIX is derived from the
clone's VMID.

The cloned virtual machine will have a newly generated MAC address and will use
an LVM snapshot of the original virtual machine's disk for storage. All other
configuration is copied from the original virtual machine.

Available OPTIONs:
  -h   display this help
EOM
    exit 1
}

while getopts "Hh" opt; do
    case "${opt}" in
        H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

[ $# -ne 1 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
src_vm_ID="${vm_ID}"
src_vm_DIR="${vm_DIR}"
vm_ID=
vm_DIR=
vm_is_running "${src_vm_ID}" && die "Cannot clone a running VM: '${src_vm_ID}'"
# shellcheck disable=SC1090
. "${src_vm_DIR}/config.sh"
src_vm_NAME="$(cat "${src_vm_DIR}/name")" || die "VM entry corrupted"

# Use a temporary working directory during creation
# XXX For now don't clean up the LV. This is deliberate, since if something
# XXX unexpected goes wrong we'd rather leak an LV than lose data.
cleanup()
{
    if [ -n "${prog_TMPDIR}" ] && [ -d "${prog_TMPDIR}" ]; then
        [ -L "${vm_NAME_LINK}" ] && rm "${vm_NAME_LINK}"
        rm -rf "${prog_TMPDIR}"
    fi
}
trap cleanup 0 INT TERM
prog_TMPDIR=$(mktemp -d ${conf_DIR:?}/clone.XXXXXXXX)

# Generate a random VM ID for the new VM and use it to derive MAC addresses
vm_ID_RAW="$(od -A n -N 3 -t x1 /dev/urandom)"
vm_ID="vm$(echo "${vm_ID_RAW}" | tr -d ' ')"
conf_VM_GUEST_MAC="${conf_NET_GUEST_OUI:?}:$(echo "${vm_ID_RAW}" | sed -e 's/ /:/g')"

# Generate the clone VM's name
vm_NAME="${src_vm_NAME}-clone-$(echo "${vm_ID_RAW}" | tr -d ' ')"
vm_NAME_LINK="${conf_DIR:?}/by-name/${vm_NAME}"

# Create the per-VM configuration entry
echo "${vm_NAME}" >"${prog_TMPDIR}/name"
cat >"${prog_TMPDIR}/config.sh" <<EOM
conf_VM_GUEST_MAC="${conf_VM_GUEST_MAC:?}"
conf_VM_MEMSZ="${conf_VM_MEMSZ:?}"
conf_VM_DISKSZ="${conf_VM_DISKSZ:?}"
conf_VM_VCPUS="${conf_VM_VCPUS:?}"
conf_VM_DISK_DEV="/dev/${conf_LVM_VG:?}/${vm_ID}-disk0"
EOM

# Generate a systemd service file
cat >"${prog_TMPDIR}/${vm_ID}.service" <<EOM
[Unit]
Description=${vm_ID}
After=network.target

[Service]
ExecStart=/usr/local/sbin/vm start -S ${vm_ID}
ExecStop=/usr/local/sbin/vm stop -S ${vm_ID}
Type=forking
Restart=no
PIDFile=${conf_STATE_DIR:?}/${vm_ID}-qemu.pid

[Install]
WantedBy=multi-user.target
EOM

# Create the logical volume
# XXX --quiet does not silence useless lvcreate informational messages,
# XXX so we redirect it to /dev/null
if [ -n "${conf_LVM_POOL}" ]; then
    lvcreate --quiet --yes \
        --name "${vm_ID}-disk0" \
        --snapshot "/dev/${conf_LVM_VG:?}/${src_vm_ID}-disk0" \
        >/dev/null \
        || die "Could not create snapshot"
    lvchange -ay -K "${conf_LVM_VG:?}/${vm_ID}-disk0" \
        || die "Could not activate snapshot"
else
    # Not supported w/o thin pools.
    die "Not supported without thin pool storage"
fi

# Commit the configuration
vm_DIR="${conf_DIR:?}/${vm_ID}"
ln -Ts "${vm_DIR}" "${vm_NAME_LINK}" \
    || die "Could not create link to '${vm_NAME}'"
mv "${prog_TMPDIR}" "${vm_DIR}" \
    || die "Could not commit configuration to '${vm_DIR}'"
echo "${vm_ID}"
exit 0
