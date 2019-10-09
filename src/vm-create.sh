#!/bin/sh

#
# Create a new VM
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="Create a new virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME

NAME is a user-visible name for the virtual machine. NAME must be composed
entirely of alphanumeric characters and '-', and must be unique.

Available OPTIONs:
  -h   display this help
  -m   configure with MEMSZ [M|G] of memory (default ${conf_VM_MEMSZ:?})
  -d   allocate and configure DISKSZ [M|G] of disk (default ${conf_VM_DISKSZ:?})
  -c   configure VCPUS number of VCPUs (default ${conf_VM_VCPUS:?})
EOM
    exit 1
}

while getopts "Hhm:d:c:" opt; do
    case "${opt}" in
        H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        h)
            usage
            ;;
        m)
            conf_VM_MEMSZ="${OPTARG}"
            ;;
        d)
            conf_VM_DISKSZ="${OPTARG}"
            ;;
        c)
            conf_VM_VCPUS="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

[ $# -ne 1 ] && usage
arg_is_safe "$1" || die "Invalid characters in NAME parameter"
(echo "$1" | grep -q '^vm[0-9]\{6\}$') && die "NAME cannot be a VMID"
vm_NAME="$1"
vm_NAME_LINK="${conf_DIR:?}/by-name/${vm_NAME}"
[ -L "${vm_NAME_LINK}" ] && die "The NAME '${vm_NAME}' is not unique"

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
prog_TMPDIR=$(mktemp -d ${conf_DIR:?}/create.XXXXXXXX)

# Sanitise memory and disk size option values (must be uppercase)
conf_VM_MEMSZ=$(echo "${conf_VM_MEMSZ:?}" | tr gm GM)
conf_VM_DISKSZ=$(echo "${conf_VM_DISKSZ:?}" | tr gm GM)

# Generate a random VM ID for the new VM and use it to derive MAC addresses
vm_ID_RAW="$(od -A n -N 3 -t x1 /dev/urandom | cut -c 2-)"
vm_ID="vm$(echo "${vm_ID_RAW}" | tr -d ' ')"
conf_VM_GUEST_MAC="${conf_NET_GUEST_OUI:?}:$(echo "${vm_ID_RAW}" | sed -e 's/ /:/g')"

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
    # Use thin provisioning from pool.
    lvcreate --quiet --yes \
        --name "${vm_ID}-disk0" \
        --virtualsize "${conf_VM_DISKSZ:?}" \
        "${conf_LVM_VG}/${conf_LVM_POOL:?}" \
        >/dev/null \
        || die "Could not create logical volume"
else
    # Use standard LVM volume from VG
    lvcreate --quiet --yes \
        --name "${vm_ID}-disk0" \
        --size "${conf_VM_DISKSZ:?}" \
        --wipesignatures y \
        "${conf_LVM_VG:?}" \
        >/dev/null \
        || die "Could not create logical volume"
fi

# Commit the configuration
vm_DIR="${conf_DIR:?}/${vm_ID}"
ln -Ts "${vm_DIR}" "${vm_NAME_LINK}" \
    || die "Could not create link to '${vm_NAME}'"
mv "${prog_TMPDIR}" "${vm_DIR}" \
    || die "Could not commit configuration to '${vm_DIR}'"
echo "${vm_ID}"
exit 0
