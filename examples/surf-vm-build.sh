#!/bin/sh
#
# Build job driver for surf-build using "vm" for ephemeral VM management.
#
# Example deployment:
#
#     $ GITHUB_USER=... GITHUB_TOKEN=... surf-run \
#         -r https://github.com/USER/REPO -- /path/to/surf-vm-build
#
# You will want to modify the list of builds and VM templates at the end
# of this script (see the calls to do_build()).

prog_NAME=$(basename $0)

log()
{
    echo "$(date -Iseconds) ${prog_NAME}[$$]: $@" 1>&2
}

err()
{
    log "ERROR: $@"
}

warn()
{
    log "WARNING: $@"
}

die()
{
    err "$@"
    exit 1
}

[ -z "${GITHUB_USER}" ]  && die "GITHUB_USER must be set"
[ -z "${GITHUB_TOKEN}" ] && die "GITHUB_TOKEN must be set"
[ -z "${SURF_REPO}" ]    && die "SURF_REPO must be set"
[ -z "${SURF_SHA1}" ]    && die "SURF_SHA1 must be set"
[ -z "${SURF_NWO}" ]     && die "SURF_NWO must be set"

gh_status()
{
    [ -z "${SURF_BUILD_NAME}" ] && die "gh_status(): SURF_BUILD_NAME not set"
    [ $# -ne 2 ] && die "gh_status(): usage: STATE DESCRIPTION"

    curl -s -f --output /dev/null --data @- \
        -u "${GITHUB_USER}:${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${SURF_NWO}/statuses/${SURF_SHA1}" \
        <<EOM
        { "context":"${SURF_BUILD_NAME}", "state":"$1", "description":"$2" }
EOM
    # Failure here is deliberately ignored
}

gh_die()
{
    gh_status error "#@"
    die "$@"
}

cleanup()
{
    if [ -n "${vm_ID}" ]; then
        sudo vm stop -f "${vm_ID}"
        sudo vm remove "${vm_ID}"
    fi
}
trap cleanup 0 INT TERM

sepa()
{
    echo -n "----------------------------------------"
    echo "----------------------------------------"
}

do_build()
{
    [ $# -ne 2 ] && die "do_build(): usage: CONTEXT TEMPLATE"
    SURF_BUILD_NAME="$1"
    vm_TEMPLATE="$2"

    sepa
    log "New job: ${SURF_NWO}@${SURF_SHA1}"
    log "Github context: ${SURF_BUILD_NAME}, VM template: ${vm_TEMPLATE}"

    vm_ID=$(sudo vm clone "${vm_TEMPLATE}") \
        || gh_die "Clone failed ($?)"
    log "Booting VM: ${vm_ID}"
    gh_status pending "Waiting for ${vm_ID}"
    sudo vm start "${vm_ID}" \
        || gh_die "Start ${vm_ID} failed ($?)"
    vm_IP=$(timeout 30 sudo vm wait "${vm_ID}") \
        || gh_die "Wait ${vm_ID} failed ($?)"
    log "Boot complete, IP address: ${vm_IP}"

    sepa

    gh_status pending "Building on ${vm_ID}"
    # This command can exit with the following status:
    #   0: Success
    #   2: The underlying surf-build job failed
    # 124: Timed out
    # 255: The SSH connection failed
    # (surf-build exits with 255 if the job failed, hence the status-juggling)
    timeout 300 ssh ${vm_IP} env - \
            PATH="/home/build/node_modules/.bin:/usr/local/bin:/usr/bin:/bin" \
            TMPDIR="/home/build" \
            GITHUB_TOKEN=${GITHUB_TOKEN} \
            SURF_REPO=${SURF_REPO} \
            SURF_SHA1=${SURF_SHA1} \
            surf-build -n "${SURF_BUILD_NAME}" \|\| exit 2
    job_STATUS=$?
    # We only want to publish timeouts or SSH failures
    case "${job_STATUS}" in
        124)
            gh_status error "Build timed out"
            job_TIMEOUT=1
            ;;
        255)
            gh_status error "Connection to ${vm_ID} failed"
            ;;
        *)
            ;;
    esac

    sepa
    log "Exit status: ${job_STATUS}"

    if [ -n "${job_TIMEOUT}" ]; then
        # If the job timed out, kill the VM with prejudice.
        # XXX Note, this will leak a DHCP lease.
        log "Job timed out, killing VM: ${vm_ID}"
        sudo vm stop -f ${vm_ID}
    else
        # Otherwise, give it some time to gracefully shut down.
        log "Stopping and removing VM: ${vm_ID}"
        sudo vm stop -t 30 ${vm_ID}
    fi
    sudo vm remove ${vm_ID}
    vm_ID=
}

do_build Test ci-solo5-debian9

log "Done"
