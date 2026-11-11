#!/bin/sh
# create for env_postcheck: reports whether SeaweedFS answers through Caddy and
# whether the deployment's credentials work, then uploads a save package if asked.
#
# Caddy is checked on the Filer's /<dir>/, which needs basic auth: it answers
# 401 without credentials and 2xx or 3xx with the right ones. Only credentials
# Caddy accepted are published as capabilities. A save or push deployment
# installs nothing, so it reports what another deployment may have installed.
set -u
# The fabric plugin leaves the settings in an env file on the VM. It holds passwords.
rm -f "$(dirname "$0")/env-$(basename "$0")"

log() { ctx logger info "$1"; }
warn() { ctx logger warning "$1"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

OFFLINE_PACKAGE_NAME="swfs-save.tar.gz"
offline_package_uploaded="false"
offline_package_url="N/A"
new_offline_package_name=""
swfs_running="false"
admin_url="N/A"
filer_url="N/A"
master_url="N/A"
s3_url="N/A"
grafana_url="N/A"
cap_username="N/A"
cap_password="N/A"

admin_port="${SWFS_ADMIN_PORT:-443}"
master_port="${SWFS_MASTER_PORT:-9333}"
filer_port="${SWFS_FILER_PORT:-8888}"
s3_port="${SWFS_S3_PORT:-8333}"
grafana_port="${GRAFANA_PORT:-3000}"
filer_dir="${DEFAULT_FILER_DIR_NAME:-artifacts}"

mgmt_ip=$(hostname -I | awk '{ print $1 }')
filer_check_url="https://${mgmt_ip}:${filer_port}/${filer_dir}/"

log "Post install check started."

# The installer waits for Caddy before it exits 0, so after an install a
# minute is plenty. save and push install nothing: one look is enough.
case "${RUN_ARG:-install}" in
    install|"install push") attempts=6 ;;
    *) attempts=1 ;;
esac

container_running=$(sudo docker inspect --format '{{.State.Running}}' seaweed-mini 2>/dev/null || echo "false")
caddy_code="000"
if [ "$container_running" = "true" ]; then
    n=0
    while [ "$n" -lt "$attempts" ]; do
        n=$((n + 1))
        caddy_code=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "$filer_check_url" 2>/dev/null) || true
        [ -n "$caddy_code" ] || caddy_code="000"
        [ "$caddy_code" != "000" ] && break
        [ "$n" -lt "$attempts" ] && sleep 10
    done
fi

if [ "$container_running" != "true" ]; then
    log "SeaweedFS is not running (no running seaweed-mini container)."
elif [ "$caddy_code" = "000" ]; then
    warn "seaweed-mini is running, but Caddy doesn't answer on ${filer_check_url}."
else
    swfs_running="true"
    admin_url="https://${mgmt_ip}:${admin_port}"
    filer_url="https://${mgmt_ip}:${filer_port}/${filer_dir}"
    master_url="https://${mgmt_ip}:${master_port}"
    s3_url="https://${mgmt_ip}:${s3_port}"
    grafana_running=$(sudo docker inspect --format '{{.State.Running}}' grafana 2>/dev/null || echo "false")
    [ "$grafana_running" = "true" ] && grafana_url="https://${mgmt_ip}:${grafana_port}"
    log "SeaweedFS is running, and Caddy answers on ${filer_check_url} (HTTP ${caddy_code} without credentials)."

    # The credentials go to curl on stdin, in a config line, so they aren't on
    # its command line. Inside its double quotes, \ and " are escaped.
    esc_user=$(printf '%s' "${SWFS_USER:-}" | sed 's/[\\"]/\\&/g')
    esc_pass=$(printf '%s' "${SWFS_PASSWORD:-}" | sed 's/[\\"]/\\&/g')
    auth_code=$(printf 'user = "%s:%s"\n' "$esc_user" "$esc_pass" \
        | curl -sk --max-time 10 -K - -o /dev/null -w '%{http_code}' "$filer_check_url" 2>/dev/null) || true
    case "$auth_code" in
        2??|3??)
            log "Caddy accepted the credentials for ${SWFS_USER} (HTTP ${auth_code})."
            cap_username="$SWFS_USER"
            cap_password="$SWFS_PASSWORD"
            ;;
        401)
            warn "SeaweedFS is running, but Caddy rejected the credentials for ${SWFS_USER}. They aren't published."
            ;;
        *)
            warn "SeaweedFS is running, but checking the credentials returned HTTP ${auth_code:-000}. They aren't published."
            ;;
    esac
fi

if [ -f "$HOME/${OFFLINE_PACKAGE_NAME}" ]; then
    log "Offline package found: ${OFFLINE_PACKAGE_NAME}"
    log "Upload package: ${UPLOAD_OFFLINE_PACKAGE:-false}"
    if [ "$(lower "${UPLOAD_OFFLINE_PACKAGE:-false}")" = "true" ]; then
        log "Uploading offline package..."
        new_offline_package_name="$(date +%Y%m%d%H%M)-${OFFLINE_PACKAGE_NAME}"
        mv "$HOME/${OFFLINE_PACKAGE_NAME}" "$HOME/${new_offline_package_name}"
        if [ -z "${UPLOAD_BASE_URL:-}" ] || [ -z "${UPLOAD_OFFLINE_PACKAGE_USER:-}" ] || [ -z "${UPLOAD_OFFLINE_PACKAGE_PASSWORD:-}" ]; then
            ctx logger error "UPLOAD_BASE_URL, UPLOAD_OFFLINE_PACKAGE_USER, or UPLOAD_OFFLINE_PACKAGE_PASSWORD is missing."
            exit 1
        fi
        offline_package_url="${UPLOAD_BASE_URL}${new_offline_package_name}"
        if ! curl -ku "${UPLOAD_OFFLINE_PACKAGE_USER}:${UPLOAD_OFFLINE_PACKAGE_PASSWORD}" \
            -X POST "$offline_package_url" \
            -F "file=@$HOME/${new_offline_package_name}"; then
            ctx logger error "Failed to upload offline package."
            exit 1
        fi
        offline_package_uploaded="true"
        log "Offline package uploaded to ${offline_package_url}."
    fi
else
    log "Offline package (${OFFLINE_PACKAGE_NAME}) not found. Skipping upload."
    OFFLINE_PACKAGE_NAME="N/A"
fi

log "Post install check completed."
# An uploaded package was renamed with a timestamp before the upload.
if [ "$offline_package_uploaded" = "true" ]; then
    ctx instance runtime-properties capabilities.offline_package_name "$new_offline_package_name"
else
    ctx instance runtime-properties capabilities.offline_package_name "$OFFLINE_PACKAGE_NAME"
fi
ctx instance runtime-properties capabilities.offline_package_uploaded "$offline_package_uploaded"
ctx instance runtime-properties capabilities.offline_package_url "$offline_package_url"
ctx instance runtime-properties capabilities.swfs_running "$swfs_running"
ctx instance runtime-properties capabilities.swfs_admin_url "$admin_url"
ctx instance runtime-properties capabilities.swfs_filer_url "$filer_url"
ctx instance runtime-properties capabilities.swfs_master_url "$master_url"
ctx instance runtime-properties capabilities.swfs_s3_url "$s3_url"
ctx instance runtime-properties capabilities.swfs_grafana_url "$grafana_url"
ctx instance runtime-properties capabilities.swfs_username "$cap_username"
ctx instance runtime-properties capabilities.swfs_password "$cap_password"
