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
  -v   be verbose

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
opt_VERBOSE=
while getopts "SHhv" opt; do
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
        v)
            opt_VERBOSE=1
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
if network_is_macvtap; then
    ip link add link "${conf_NET_IF:?}" \
        name "${vm_NET_IF}" \
        address "${conf_VM_GUEST_MAC:?}" \
        type macvtap mode bridge \
        || die "Could not create network interface: \"${vm_NET_IF}\""
elif network_is_bridge; then
    ip tuntap add mode tap name "${vm_NET_IF}" \
        || die "Could not create network interface: \"${vm_NET_IF}\""
    ip link set "${vm_NET_IF}" master "${conf_NET_IF:?}" \
        || die "Could not add network interface \"${vm_NET_IF}\" to bridge \"${conf_NET_IF}\""
else
    die "Invalid conf_NET_MODE"
fi
trap cleanup 0 INT TERM
ip link set dev "${vm_NET_IF}" up \
    || die "Could not bring up network interface: \"${vm_NET_IF}\""
if network_is_macvtap; then
    vm_NET_TAP_DEV=/dev/"$(basename "$(echo "/sys/devices/virtual/net/${vm_NET_IF}/tap"*)")"
    if [ ! -c "${vm_NET_TAP_DEV}" ]; then
        die "TAP device \"${vm_NET_TAP_DEV}\" for interface \"${vm_NET_IF}\" does not exist"
    fi
    [ -n "${opt_VERBOSE}" ] && \
        info "Using interface ${vm_NET_IF}<${conf_VM_GUEST_MAC}>@${conf_NET_IF}, macvtap /dev/${vm_NET_TAP_DEV}"
elif network_is_bridge; then
        info "Using interface ${vm_NET_IF}<${conf_VM_GUEST_MAC}>@${conf_NET_IF}"
fi

if [ ${conf_VM_VCPUS:?} -gt 1 ]; then
    qemu_SMP="-smp ${conf_VM_VCPUS}"
else
    qemu_SMP=
fi

run_qemu()
{
    # shellcheck disable=SC2154 disable=SC2086
    exec \
    ${_attach} \
    unshare -n \
    qemu-system-x86_64 \
    -daemonize \
    -name "${vm_ID}" \
    -machine q35 \
    -cpu host,migratable=no,+invtsc \
    -enable-kvm \
    ${qemu_SMP} \
    -m "${conf_VM_MEMSZ:?}" \
    -netdev tap,id=net0,fd=3 \
    -device "virtio-net-pci,netdev=net0,mac=${conf_VM_GUEST_MAC:?}" \
    -drive "if=none,id=sda,file=${conf_VM_DISK_DEV:?},format=raw,discard=on" \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=sda \
    -device virtio-rng-pci \
    -monitor "unix:${conf_STATE_DIR:?}/${vm_ID}-qemu.sock,server,nowait" \
    -vnc "unix:${conf_STATE_DIR:?}/${vm_ID}-vnc.sock" \
    -pidfile "${conf_STATE_DIR:?}/${vm_ID}-qemu.pid" \
    -chroot "${conf_VMM_CHROOT:?}" \
    -runas "${conf_VMM_USER:?}" \
    "$@"
}

umask 077 || die "umask failed"
cd / || die "cd failed"

# This rigmarole is so that we can pass both a macvtap device and a
# conventional tap device to QEMU in the same way, i.e. as file descriptor 3.
# So much for Linux API consitency.
if network_is_macvtap; then
    [ -n "${opt_VERBOSE}" ] && set -x
    _attach="" run_qemu "$@" 3<>"${vm_NET_TAP_DEV}"
elif network_is_bridge; then
    [ -n "${opt_VERBOSE}" ] && set -x
    _attach="/usr/local/lib/vm/tap_attach ${vm_NET_IF:?}" run_qemu "$@"
else
    die "Invalid conf_NET_MODE"
fi
