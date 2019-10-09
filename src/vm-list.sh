#!/bin/sh

#
# List all configured VMs
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="List configured virtual machines"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ]

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

[ $# -ne 0 ] && usage

vms=$(ls -d ${conf_DIR}/vm* 2>/dev/null)
for vm_DIR in ${vms}; do
    [ ! -d "${vm_DIR}" ] && die "Invalid configuration: \"${vm_DIR}\""
    [ ! -f "${vm_DIR}/name" ] && die "Invalid configuration: \"${vm_DIR}\""
    [ ! -f "${vm_DIR}/config.sh" ] && die "Invalid configuration: \"${vm_DIR}\""
    echo "$(basename "${vm_DIR}") ($(cat "${vm_DIR}/name"))"
done
exit 0
