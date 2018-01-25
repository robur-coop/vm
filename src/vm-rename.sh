#!/bin/sh

#
# Rename a VM
#

prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))
prog_LIBDIR=${prog_DIR}
. ${prog_LIBDIR}/functions.sh
. /etc/vm/config.sh

prog_SUMMARY="Rename a virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID TARGET

Rename the user-visible name of the virtual machine specified by NAME or VMID
to TARGET, which must be unique.

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
shift $((${OPTIND}-1))

[ $# -ne 2 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
arg_is_safe "$2" || die "Invalid characters in TARGET parameter"
(echo "$2" | grep -q '^vm[0-9]\{6\}$') && die "TARGET cannot be a VMID"
vm_SOURCE_LINK="${conf_DIR}/by-name/$(cat ${vm_DIR}/name)"
vm_TARGET_NAME="$2"
vm_TARGET_LINK="${conf_DIR}/by-name/${vm_TARGET_NAME}"

# This is redundant, but gives a friendly error message.
[ -L "${vm_TARGET_LINK}" ] && die "The TARGET '${vm_TARGET}' is not unique"

# The following ln call will fail if the target already exists (e.g. because
# someone else created it in the mean time). In that case we can safely just
# abort.
ln -PT "${vm_SOURCE_LINK}" "${vm_TARGET_LINK}" \
    || die "Could not create TARGET by-name link"
rm "${vm_SOURCE_LINK}" \
    || die "Could not remove source by-name link"
echo "${vm_TARGET_NAME}" >${vm_DIR}/name

exit 0
