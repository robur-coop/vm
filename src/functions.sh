#shellcheck shell=sh

#
# Common functions for VM management
#

err()
{
    echo "${prog_NAME:?}: ERROR: " "$@" 1>&2
}

warn()
{
    echo "${prog_NAME:?}: WARNING: " "$@" 1>&2
}

die()
{
    err "$@"
    exit 1
}

# Verify that $1 contains only "safe" characters. Used for components of path
# names (VM names, etc.) so be conservative here.
arg_is_safe()
{
    [ $# -eq 1 ] || die "arg_is_safe(): missing ARG"
    echo "$1" | grep -q '^[0-9A-Za-z-]\+$'
}

# Safely look up a VM by its NAME or VMID.
#
# Sanitises $1 to ensure that only legal values for NAME and VMID are used.
# On success, sets ${vm_DIR}, ${vm_ID} and returns true. On failure,
# returns false.
safe_lookup_vm()
{
    [ $# -eq 1 ] || die "safe_lookup_vm(): missing VMID/NAME"
    arg_is_safe "$1" || die "Illegal VMID/NAME supplied"
    if [ -d "${conf_DIR:?}/$1" ]; then
        vm_DIR="${conf_DIR:?}/$1"
        vm_ID="$1"
        return 0
    else
        vm_DIR=$(readlink -e "${conf_DIR:?}/by-name/$1") || return 1
        # shellcheck disable=SC2034
        vm_ID=$(basename "${vm_DIR}")
    fi
}

vm_exists()
{
    [ $# -eq 1 ] || die "vm_exists(): missing VMID"
    [ -d "${conf_DIR:?}/$1" ]
}

vm_is_running()
{
    [ $# -eq 1 ] || die "vm_is_running(): missing VMID"
    vm_exists "$1" && \
        [ -f "${conf_STATE_DIR:?}/$1-qemu.pid" ] && \
        [ -S "${conf_STATE_DIR:?}/$1-qemu.sock" ] && \
        [ -d "/proc/$(cat "${conf_STATE_DIR:?}/$1-qemu.pid")" ]
}

vm_is_managed()
{
    [ $# -eq 1 ] || die "vm_is_managed(): missing VMID"
    systemctl is-enabled "$1.service" >/dev/null 2>&1
}
