#!/bin/sh

#
# Shutdown a VM
#

prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))
prog_LIBDIR=${prog_DIR}
. ${prog_LIBDIR}/functions.sh
. /etc/vm/config.sh

prog_SUMMARY="Stop a virtual machine"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID

Shut down the virtual machine specified by NAME or VMID. The default behaviour
is to send the guest operating system an ACPI shutdown signal and wait for the
QEMU process to exit.

Available OPTIONs:
  -h           display this help
  -f           force immediate power off
  -t TIMEOUT   wait TIMEOUT seconds, then force power off
  -S           bypass systemd check (used to start VM as a systemd unit)

EOM
    exit 1
}

opt_FORCE=
opt_TIMEOUT=
opt_SYSTEMD=
while getopts "SHhft:" opt; do
    case "${opt}" in
        H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        h)
            usage
            ;;
        f)
            opt_FORCE=1
            ;;
        t)
            opt_TIMEOUT="timeout ${OPTARG}"
            ;;
        S)
            opt_SYSTEMD=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((${OPTIND}-1))

[ $# -ne 1 ] && usage
safe_lookup_vm "$1" || die "No such VM: '$1'"
vm_is_running "${vm_ID}" || die "VM not running: '${vm_ID}'"
if [ -z "${opt_SYSTEMD}" ]; then
    vm_is_managed "${vm_ID}" && die "VM is managed by systemd: '${vm_ID}'"
fi

if [ -n "${opt_FORCE}" ]; then
    command=quit
else
    command=system_powerdown
fi

send_qemu_command()
{
    echo $1 | ${opt_TIMEOUT} \
        socat -,ignoreeof UNIX-CONNECT:"${conf_STATE_DIR}/${vm_ID}-qemu.sock" \
        >/dev/null
}

if [ -n "${opt_FORCE}" ]; then
    send_qemu_command quit || die "Error sending QEMU command"
else
    send_qemu_command system_powerdown
    STATUS=$?
    if [ ${STATUS} -eq 124 ]; then
        warn "Timed out shutting down VM '${vm_ID}', forcing power off"
        send_qemu_command quit || die "Error sending QEMU command"
    elif [ ${STATUS} -ne 0 ]; then
        die "Error sending QEMU command"
    fi
fi

# On successful shutdown, clean up network interface and QEMU cruft
ip link del ${vm_ID}.0
rm -f "${conf_STATE_DIR}/${vm_ID}-qemu.sock"
rm -f "${conf_STATE_DIR}/${vm_ID}-vnc.sock"
rm -f "${conf_STATE_DIR}/${vm_ID}-qemu.pid"

exit 0
