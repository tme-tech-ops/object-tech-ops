# object-tech-ops

Object storage and monitoring stack for edge-cloud-init based VM deployments.

## Overview

This blueprint deploys **SeaweedFS** with a **Caddy** reverse proxy on an existing VM provisioned by the `edge-cloud-init` blueprint from the tme-tech-ops suite. It optionally includes a full monitoring stack (Grafana, Loki, Prometheus) and exposes storage via S3, SMB, and NFS protocols.

## Prerequisites

This blueprint **must be deployed on top of an existing `edge-cloud-init` deployment** from the tme-tech-ops suite. The target VM deployment is referenced via the `vm_deployment_id` input and must carry the labels:

- `csys-obj-type: environment`
- `solution: edge-cloud-init`

## Required Secrets

| Secret | Type | Description |
|--------|------|-------------|
| SSH Private Key | `secret_key` | SSH private key for the VM user, sourced from the `edge-cloud-init` deployment. Referenced by `ssh_user_private_key`. |
| Registry Authentication Secret | `basic_auth_credentials` | Username and password for a local container registry. Required when using `install push` or `push` run tasks, or installing from a local registry in offline mode. |
| Offline Binary Configuration Secret | `binary_configuration` | URL, username, access token, and version of the offline archive binary. Required only when **Airgapped Mode** is enabled. |
| Upload URL Secret | `binary_configuration` | Points to the upload destination for the offline archive (e.g. `https://myfileserver.lab/upload_dir/`). Required only when **Upload save package** is enabled. |

## Inputs

### Deployment Target

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| POC VM Deployment Instance | `vm_deployment_id` | *(required)* | The deployment ID of the existing `edge-cloud-init` VM deployment to target. |
| SSH Private Key Secret | `ssh_user_private_key` | *(optional)* | Name of the SSH private key secret in the secret store for the VM user. |

### SeaweedFS Configuration

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| Host FQDN | `host_fqdn` | `""` | Base FQDN for the host (e.g. `myhost.edge.lab`). Used to construct sub-domain FQDNs for each service. Caddy generates TLS certificates automatically per sub-domain. Leave blank to use `hostname.edge.lab`. |
| SeaweedFS Container Image | `swfs_image` | `chrislusf/seaweedfs:latest` | Container image for SeaweedFS. |
| Caddy Container Image | `caddy_image` | `caddy:latest` | Container image for Caddy reverse proxy. |
| SeaweedFS Username | `swfs_user` | `admin` | Username for SeaweedFS Admin UI, Filer, Master, SMB, and Grafana. |
| SeaweedFS Password | `swfs_password` | `changeme` | Password for SeaweedFS Admin UI, Filer, Master, SMB, and Grafana. |
| Admin FQDN | `swfs_admin_fqdn` | `""` | FQDN for SeaweedFS Admin UI and Caddy landing page. Defaults to `admin.<HOST_FQDN>` if left empty. |
| Admin Port | `swfs_admin_port` | `443` | TCP port for the SeaweedFS Admin UI / Caddy HTTPS endpoint. |
| Master FQDN | `swfs_master_fqdn` | `""` | FQDN for SeaweedFS Master UI/API. Defaults to `master.<HOST_FQDN>` if left empty. |
| Master Port | `swfs_master_port` | `9333` | TCP port for SeaweedFS Master UI/API. |
| Enable Message Queue | `enable_mq` | `true` | Deploy SeaweedMQ message broker alongside SeaweedFS. |
| Message Queue Broker Port | `mq_broker_port` | `17777` | TCP port for SeaweedMQ message broker. |

### Object Storage Configuration

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| Filer FQDN | `swfs_filer_fqdn` | `""` | FQDN for SeaweedFS Filer UI/API. Defaults to `filer.<HOST_FQDN>` if left empty. |
| Filer Port | `swfs_filer_port` | `8888` | TCP port for SeaweedFS Filer UI/API. |
| Default Filer Directory | `default_filer_dir_name` | `artifacts` | Default directory name on SeaweedFS Filer for artifacts. |
| Artifacts to Download | `artifacts_to_download` | `""` | List of artifact URLs to auto-download with curl and upload to the SeaweedFS Filer. |
| S3 FQDN | `swfs_s3_fqdn` | `""` | FQDN for SeaweedFS S3 API. Defaults to `s3.<HOST_FQDN>` if left empty. |
| S3 Port | `swfs_s3_port` | `8333` | TCP port for SeaweedFS S3 API. |
| S3 User | `s3_user` | `admin` | S3 user name. Defaults to the SeaweedFS username if left empty. |
| Default S3 Bucket | `s3_bucket` | `charlie` | Name of the default S3 bucket created in SeaweedFS. |
| Enable SMB Share | `enable_smb` | `true` | Install and configure Samba to expose the SeaweedFS FUSE mount as an SMB share. |
| Enable NFS Export | `enable_nfs` | `true` | Install and configure NFS to export the SeaweedFS FUSE mount. |

### Monitoring Configuration

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| Enable Monitoring Stack | `enable_monitoring` | `false` | Deploy Grafana, Loki, and Prometheus monitoring stack alongside SeaweedFS. |
| Loki Container Image | `loki_image` | `grafana/loki:3.4.2` | Container image for Grafana Loki log aggregation. |
| Grafana Container Image | `grafana_image` | `grafana/grafana-oss:11.5.2` | Container image for Grafana OSS dashboard. |
| Prometheus Container Image | `prometheus_ext_image` | `prom/prometheus:v3.2.1` | Container image for Prometheus metrics collector. |
| Grafana FQDN | `grafana_fqdn` | `""` | FQDN for Grafana UI proxied through Caddy. Defaults to `grafana.<HOST_FQDN>` if left empty. |
| Grafana Port | `grafana_port` | `3000` | External TCP port for Grafana UI. |
| Loki Port | `loki_port` | `3100` | TCP port for Loki push/query endpoint (direct, no TLS). |
| Prometheus Port | `prometheus_ext_port` | `9090` | External TCP port for Prometheus remote-write receiver. |
| Loki S3 Bucket | `loki_bucket` | `loki-logs` | S3 bucket name used for Loki log storage. |
| Cluster Name | `cluster_name` | `edge-lab` | Label applied to all monitoring metrics and logs for cluster identification. |

### Environment Configuration

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| Install Task | `run_arg` | `install` | Operation to perform. Options: `install` (from internet), `install push` (install and push images to local registry), `save` (create offline archive), `push` (push saved images to local registry). Mutually exclusive with Airgapped Mode. |
| Script URL | `script_url` | *(installer script URL)* | URL of the installation script to execute. Mutually exclusive with Airgapped Mode. |
| Airgapped Mode | `offline_mode` | `false` | Set to `true` to download and install from the specified offline package. |
| Offline Binary Configuration Secret | `offline_binary_secret` | *(optional)* | Secret containing the URL, username, access token, and version of the offline archive binary. Only shown when Airgapped Mode is enabled. |
| Registry Authentication Secret | `registry_secret` | *(optional)* | Secret containing username and password for a local container registry. Required for `install push` or `push` tasks, or offline installs from a local registry. |
| Registry URL | `registry_url` | `""` | URL of the local container registry (e.g. `myregistry.lab:5000`). |
| Upload save package | `upload_package` | `false` | Only for the `save` install task. Uploads the offline archive to a file server after creation. |
| Upload URL location | `upload_binary_secret` | *(optional)* | Binary configuration secret pointing to the upload destination. Only shown when Upload save package is enabled. |
| Log Output to hide | `hide_log_output` | `["stdout"]` | Controls which output streams are suppressed. Options: `stdout`, `stderr`, `both`. |
| Debug Logging | `debug` | `1` | Set to `1` to enable debug logging, `0` to disable. |

## Outputs

After a successful deployment the following capabilities are available:

| Output | Description |
|--------|-------------|
| `swfs_username` | SeaweedFS admin username |
| `swfs_password` | SeaweedFS admin password |
| `swfs_running` | SeaweedFS service running status |
| `swfs_admin_url` | SeaweedFS Admin UI URL (via IP address) |
| `swfs_filer_url` | SeaweedFS Filer browser URL (via IP address) |
| `swfs_master_url` | SeaweedFS Master console URL (via IP address) |
| `swfs_s3_url` | SeaweedFS S3 API URL (via IP address) |
| `swfs_grafana_url` | Grafana dashboard URL (N/A if monitoring disabled) |
| `offline_package_name` | Name of the offline archive (save operation only) |
| `offline_package_uploaded` | Whether the offline archive was uploaded |
| `offline_package_url` | URL where the offline archive was uploaded |
