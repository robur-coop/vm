#!/bin/sh

#
# Run a VM
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="Start a virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID [ QEMU OPTIONS ... ]

Launches the virtual machine specified by NAME or VMID.

Additional QEMU OPTIONS may be specified after the command options, these
will be passed on to QEMU verbatim.

Available OPTIONs:
  -h   display this help
  -S   bypass systemd check (used to start VM as a systemd unit)

EOM
    exit 1
}

cleanup()
{
    # Clean up network interface if present
    [ -n "${vm_NET_IF}" ] && \
        [ -d "/sys/devices/virtual/net/${vm_NET_IF}" ] && \
        ip link del "${vm_NET_IF}"
}

opt_SYSTEMD=
while getopts "SHh" opt; do
    case "${opt}" in
        H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        h)
            usage
            ;;
        S)
            opt_SYSTEMD=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

[ $# -lt 1 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
shift
vm_is_running "${vm_ID}" && die "VM already running: '${vm_ID}'"
if [ -z "${opt_SYSTEMD}" ]; then
    vm_is_managed "${vm_ID}" && die "VM is managed by systemd: '${vm_ID}'"
fi
# shellcheck disable=SC1090
. "${vm_DIR}/config.sh"

# Verify that LVM volume containing disk exists
[ -b "${conf_VM_DISK_DEV:?}" ] \
    || die "Disk device does not exist: \"${conf_VM_DISK_DEV}\""

# Create network interface
vm_NET_IF="${vm_ID}.0"
if [ -d "/sys/devices/virtual/net/${vm_NET_IF}" ]; then
    err "Network interface \"${vm_NET_IF}\" already exists."
    err "This probably means that the VM was not shut down correctly."
    die "Please clean up manually."
fi
ip link add link "${conf_NET_IF:?}" \
    name "${vm_NET_IF}" \
    address "${conf_VM_GUEST_MAC:?}" \
    type macvtap mode bridge \
    || die "Could not create network interface: \"${vm_NET_IF}\""
trap cleanup 0 INT TERM
ip link set dev "${vm_NET_IF}" up \
    || die "Could not bring up network interface: \"${vm_NET_IF}\""
vm_NET_TAP_DEV=/dev/"$(basename "$(echo "/sys/devices/virtual/net/${vm_NET_IF}/tap"*)")"
if [ ! -c "${vm_NET_TAP_DEV}" ]; then
    die "TAP device \"${vm_NET_TAP_DEV}\" for interface \"${vm_NET_IF}\" does not exist"
fi

### echo "network: Using macvtap ${vm_NET_IF}<${conf_VM_GUEST_MAC}>, /dev/${vm_NET_TAP_DEV}"

if [ ${conf_VM_VCPUS:?} -gt 1 ]; then
    qemu_SMP="-smp ${conf_VM_VCPUS}"
else
    qemu_SMP=
fi

# XXX For non-SCSI (virtio-blk) drive use:
# -drive if=virtio,file=${conf_VM_DISK_DEV},format=raw,discard=on
run_qemu()
{
    umask 077 || return 1
    cd / || return 1
    exec unshare -n qemu-system-x86_64 -daemonize \
        -name "${vm_ID}" \
        -machine q35 \
        -cpu host,migratable=no,+invtsc \
        -enable-kvm \
        ${qemu_SMP} \
        -m "${conf_VM_MEMSZ:?}" \
        -net "nic,model=virtio,macaddr=${conf_VM_GUEST_MAC:?}" \
        -net tap,fd=3 \
        -drive "if=none,id=sda,file=${conf_VM_DISK_DEV:?},format=raw,discard=on" \
        -device virtio-scsi-pci,id=scsi0 \
        -device scsi-hd,drive=sda \
        -device virtio-rng-pci \
        -monitor "unix:${conf_STATE_DIR:?}/${vm_ID}-qemu.sock,server,nowait" \
        -vnc "unix:${conf_STATE_DIR:?}/${vm_ID}-vnc.sock" \
        -pidfile "${conf_STATE_DIR:?}/${vm_ID}-qemu.pid" \
        -chroot "${conf_VMM_CHROOT:?}" \
        -runas "${conf_VMM_USER:?}" \
        "$@" \
         3<>"${vm_NET_TAP_DEV}" \
    || die "Could not exec qemu-system-x86_64"
}

### echo "qemu: ${qemu_OPT}"

run_qemu "$@"
