#!/bin/sh

#
# Shutdown a VM
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="Export a virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID IMAGE

Export the virtual machine specified by NAME or VMID to the compressed QCOW2
format file specified by IMAGE.

Available OPTIONs:
  -h           display this help

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

[ $# -ne 2 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
vm_is_running "${vm_ID}" && die "VM is running: '${vm_ID}'"
[ -f "$2" ] && die "File already exists: '$2'"
# shellcheck disable=SC1090
. "${vm_DIR}/config.sh"
# shellcheck disable=SC2154
qemu-img convert -O qcow2 -T none -t none -c "${conf_VM_DISK_DEV}" "$2" \
    || die "qemu-img convert failed"

exit 0
