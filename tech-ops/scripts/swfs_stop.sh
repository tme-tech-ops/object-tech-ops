#!/bin/sh
set -u

# stop for install_app.
#
# SeaweedFS and its data (objects, the Caddy CA that clients trust, monitoring)
# are removed only when this deployment is uninstalled, and only if its Install
# Task installed SeaweedFS (install, install push). save and push deployments
# didn't.
#
# Other workflows run stop too: a reinstall during an update ("Run automatic
# reinstall" or a reinstall list) and Heal. In those SeaweedFS stays as it is.

workflow="$(ctx workflow-id 2>/dev/null || echo unknown)"

case "${workflow}" in
    uninstall)
        case "${RUN_ARG:-install}" in
            install|"install push")
                if [ -x ~/install-seaweedfs ]; then
                    ctx logger info "Uninstalling SeaweedFS (Install Task '${RUN_ARG:-install}')."
                    cd ~ && sudo -E ./install-seaweedfs uninstall
                else
                    ctx logger info "install-seaweedfs not found in the home directory: nothing to uninstall."
                fi
                ;;
            *)
                ctx logger info "Install Task '${RUN_ARG}' didn't install SeaweedFS: nothing to uninstall."
                ;;
        esac
        ;;
    *)
        ctx logger info "Keeping SeaweedFS and its data (${workflow} workflow): only uninstalling the deployment removes them."
        ;;
esac
