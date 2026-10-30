#!/bin/sh
set -u

# create for install_app: runs install-seaweedfs with the command env_precheck
# assembled (INSTALL_CMD).
#
# Outside the install workflow (a reinstall during an update, a reinstall list,
# Heal) an installed, running SeaweedFS is kept as it is: a re-run of the
# installer would issue new random S3 keys and lock out existing S3 clients.

workflow="$(ctx workflow-id 2>/dev/null || echo unknown)"

if [ "${workflow}" != "install" ] && sudo test -f /opt/seaweedfs/.install-state \
        && sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -qx seaweed-mini; then
    ctx logger info "SeaweedFS is installed and running: keeping it and its S3 keys (${workflow} workflow)."
    exit 0
fi

cd ~ && sudo -E ./install-seaweedfs ${INSTALL_CMD}
