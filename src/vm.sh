#!/bin/sh

#
# VM CLI frontend
#

prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))
if [ -n "${VM_MAINTAINER_MODE}" ]; then
    echo "${prog_NAME}: WARNING: Maintainer mode is on" 1>&2
    prog_LIBDIR=${prog_DIR}
else
    prog_LIBDIR=/usr/local/share/vm
fi
. ${prog_LIBDIR}/functions.sh
. /etc/vm/config.sh

prog_SUMMARY="Manage virtual machines"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} COMMAND [ OPTIONS ... ]

Available COMMANDs:
EOM
    for command in ${prog_LIBDIR}/vm-*.sh; do
        name=$(echo "${command}" | sed -ne 's/^.\+vm-\([a-z]\+\).sh$/\1/p')
        summary=$(${command} -H)
        printf "  %-14s%s\n" "${name}" "${summary}" 1>&2
    done
    cat 1>&2 <<EOM

Run '${prog_NAME} COMMAND -h' for more information on a command.
EOM
    exit 1
}

if [ $# -lt 1 ]; then
    usage
elif [ ! -x "${prog_LIBDIR}/vm-$1.sh" ]; then
    err "Unknown command: $1"
    usage
else
    command="$1"
    shift
    exec "${prog_LIBDIR}/vm-${command}.sh" "$@"
fi
