#!/bin/sh

#
# Wait for a VM to come online
#

prog_NAME=$(basename $0)
prog_DIR=$(readlink -f $(dirname $0))
prog_LIBDIR=${prog_DIR}
. ${prog_LIBDIR}/functions.sh
. /etc/vm/config.sh

prog_SUMMARY="Wait for a virtual machine to come online"
usage()
{
    cat 1>&2 <<EOM

${prog_SUMMARY}

usage: ${prog_NAME} [ OPTIONS ... ] NAME | VMID

Wait for the virtual machine specified by NAME or VMID to come online. This is
accomplished by waiting for the virtual machine's hostname to appear in the
DNS server's zone, followed by waiting for a successful connection to a SSH
service on the virtual machine.

Available OPTIONs:
  -h           display this help
  -p PORT      connect to service on port PORT (default: 22)

EOM
    exit 1
}

opt_PORT=22
while getopts "Hhp:" opt; do
    case "${opt}" in
        H)
            echo "${prog_SUMMARY}"
            exit 0
            ;;
        h)
            usage
            ;;
        p)
            opt_PORT="${OPTARG}"
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

# Translate the vm_ID back to the DNS name (see /etc/vm/config.sh)
type vmid_to_dns >/dev/null 2>&1 \
    || die "vmid_to_dns() not defined"
vmid_to_dns
[ -z "${vm_DNS_NAME}" ] && die "Cannot translate '${vm_ID}' to DNS name"

while ! vm_IP_ADDRESS=$(host -t A -4 -r "${vm_DNS_NAME}"); do
    sleep 1
done
vm_IP_ADDRESS="$(echo "${vm_IP_ADDRESS}" | cut -d' ' -f4)"

while ! socat /dev/null "TCP4:${vm_IP_ADDRESS}:${opt_PORT}"; do
    sleep 1
done

echo ${vm_IP_ADDRESS}

