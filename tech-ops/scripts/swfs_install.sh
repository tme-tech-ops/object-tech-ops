#!/bin/sh
# create for install_app: runs ~/install-seaweedfs for the Install Task, with
# the deployment's settings in the environment.
#
# Outside the install workflow (a reinstall during an update, a reinstall list,
# Heal) an installed, running SeaweedFS is kept as it is. On a VM that 1.2.0.0
# installed, ~/install-seaweedfs is installer v1.0.0, and a re-run would issue
# new random S3 keys and lock out S3 clients. v1.1.0 and later keep the keys,
# and v1.3.0 leaves Samba and NFS running when a run changes nothing.
set -u
# The fabric plugin leaves the settings in an env file on the VM. It holds passwords.
rm -f "$(dirname "$0")/env-$(basename "$0")"

log() { ctx logger info "$1"; }
fail() { ctx logger error "$1"; exit 1; }

workflow="$(ctx workflow-id 2>/dev/null || echo unknown)"

if [ "${workflow}" != "install" ] && sudo test -f /opt/seaweedfs/.install-state \
        && sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -qx seaweed-mini; then
    log "SeaweedFS is installed and running: keeping it and its S3 keys (${workflow} workflow)."
    exit 0
fi

task="${RUN_ARG:-install}"
case "$task" in
    install) set -- install ;;
    "install push") set -- install push ;;
    save) set -- save ;;
    push) set -- push ;;
    *) fail "Unknown Install Task '${task}'." ;;
esac

# The installer refuses -registry with save. install and install push use the
# registry for the images; push needs it.
reg_url="${REG_URL:-}"
[ "$reg_url" = "None" ] && reg_url=""
shown="$*"
if [ -n "$reg_url" ] && [ "$task" != "save" ]; then
    [ -n "${REG_USER:-}" ] && [ -n "${REG_PASS:-}" ] \
        || fail "Registry URL is set, but the Registry Authentication Secret gave no username or password."
    set -- "$@" -registry "$reg_url" "$REG_USER" "$REG_PASS"
    shown="${shown} -registry ${reg_url} ${REG_USER} ****"
elif [ -n "$reg_url" ]; then
    log "Install Task save doesn't use the registry: Registry URL is ignored."
fi
case "$task" in
    push|"install push")
        [ -n "$reg_url" ] || fail "Install Task '${task}' needs Registry URL and the Registry Authentication Secret."
        ;;
esac

# Online, ignore a swfs-save-version.txt that an earlier save left in the home
# directory: it would switch the installer to the offline package. push keeps
# the installer's detection, so it pushes a save bundle's images when one is there.
offline_mode=$(printf '%s' "${OFFLINE_MODE:-false}" | tr '[:upper:]' '[:lower:]')
if [ "$offline_mode" != "true" ] && [ "$task" != "push" ]; then
    SWFS_FORCE_ONLINE=true
    export SWFS_FORCE_ONLINE
fi

cd ~ || fail "No home directory."
[ -x ./install-seaweedfs ] || fail "~/install-seaweedfs is missing: env_precheck didn't put it there."
log "Running: install-seaweedfs ${shown}"
sudo -E ./install-seaweedfs "$@"
