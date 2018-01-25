#!/bin/sh

#
# Remove a VM, deleting its resources permanently
#

prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))
prog_LIBDIR=${prog_DIR}
. ${prog_LIBDIR}/functions.sh
. /etc/vm/config.sh

prog_SUMMARY="Remove a virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID

Permanently deletes the virtual machine specified by NAME or VMID, including
all its configuration and resources.

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
shift $((${OPTIND}-1))

[ $# -ne 1 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
vm_is_running "${vm_ID}" && die "Cannot remove running VM: '${vm_ID}'"
. ${vm_DIR}/config.sh

# XXX --quiet does not silence useless lvremove informational messages,
# XXX so we redirect it to /dev/null
lvremove --quiet --yes ${conf_VM_DISK_DEV} >/dev/null \
    || die "Could not remove logical volume"
rm "${conf_DIR}/by-name/$(cat ${vm_DIR}/name)" || die "rm link failed"
( cd ${vm_DIR} && rm * ) || die "rm failed"
rmdir ${vm_DIR} || die "rmdir failed"

exit 0
