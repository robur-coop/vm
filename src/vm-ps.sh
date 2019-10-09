#!/bin/sh

#
# Show running virtual machines
#

prog_NAME=$(basename "$0")
prog_DIR=$(readlink -f "$(dirname "$0")")
prog_LIBDIR=${prog_DIR}
# shellcheck source=src/functions.sh
. "${prog_LIBDIR}/functions.sh"
# shellcheck source=config.sh.dist
. /etc/vm/config.sh

prog_SUMMARY="Show running virtual machines"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] [ ARGS ... ]

Additional ARGS, if any, will be passed through to 'ps'.

Available OPTIONs:
  -h   display this help
EOM
    exit 1
}

# We can't use getopts here, so just check for -h / -H as initial arguments
# and pass anything else on to "ps".
if [ $# -gt 0 ]; then
    case "$1" in
        -H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        -h)
            usage
            ;;
    esac
fi

exec ps -U "${conf_VMM_USER}" -o pid,time,command "$@"
