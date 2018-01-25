#!/bin/sh

# NOTE: This subcommand does not rely on any global configuration or shared
# functions. This is so that it can be easily installed standalone on client
# systems to provide the SSH forwarding functionality.
prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))

err()
{
    echo "${prog_NAME}: ERROR: $@" 1>&2
}

warn()
{
    echo "${prog_NAME}: WARNING: $@" 1>&2
}

die()
{
    err "$@"
    exit 1
}

prog_SUMMARY="Connect to a virtual machine's console"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] [ HOST: ] VMID [ VNC OPTIONS ]

Connect to the console of the virtual machine identified by VMID.

If HOST: is specified, forwards the VNC connection over SSH to root@HOST.
Any additional VNC OPTIONS specified are passed through to "ssvncviewer".

Available OPTIONs:
  -h           display this help
       
EOM
    exit 1
}

while getopts "Hhft:" opt; do
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

[ $# -lt 1 ] && usage

HOST=${1%%:*}
vm_ID=${1##*:}
shift
if [ "${HOST}" = "${vm_ID}" ]; then
    HOST=
fi

if [ -n "${HOST}" ]; then
    cleanup()
    {
	if [ -n "${TMPDIR}" -a -d "${TMPDIR}" ]; then
	    [ -S "${CONTROL}" ] && ssh -S ${CONTROL} -O exit localhost
	    rm -rf ${TMPDIR}
	fi
    }
    trap cleanup 0 INT TERM 
    TMPDIR=$(mktemp -d)
    CONTROL=${TMPDIR}/ssh.sock
    LOCAL=${TMPDIR}/vnc.sock
    REMOTE=/var/run/${vm_ID}-vnc.sock

    ssh -nMNfS ${CONTROL} -o ExitOnForwardFailure=yes \
	-L ${LOCAL}:${REMOTE} \
	root@${HOST} \
	|| exit 1
else
    LOCAL=/var/run/${vm_ID}-vnc.sock
fi

ssvncviewer unix=${LOCAL} "$@"
