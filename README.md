# object-tech-ops

Blueprint for deploying object storage and monitoring stack for **edge-cloud-init** based VM deployments.  
  
This blueprint is designed for **NativeEdge Endpoints** on **Dell Automation Platform**

## Overview

This blueprint deploys **SeaweedFS** with a **Caddy** reverse proxy on an existing VM provisioned by the `edge-cloud-init` blueprint from the tme-tech-ops suite. It optionally includes a full monitoring stack (Grafana, Loki, Prometheus) and exposes storage via S3, SMB, and NFS protocols.

## Releases

| Release | DAP | DDPC | Version | Tested |
|---|---|---|---|---|
| [`1.2.0.0`](https://github.com/tme-tech-ops/object-tech-ops/releases/tag/1.2.0.0) | 2.1.1.0 | 4.3.0.0 | 1.2.0.0 | yes |
| [`1.1.5.0`](https://github.com/tme-tech-ops/object-tech-ops/releases/tag/1.1.5.0) | 2.0.0.1 | 4.2.0.0 | 1.1.5.0 (branch `ddpc-4.2.0.0-snapshot`) | no |

Download the zip attached to the release that matches your DAP and DDPC versions (not
"Source code"); its notes give the blueprint name, revision and upload order.

### SeaweedFS installer

Each version runs a fixed release of
[seaweedfs-installer](https://github.com/Chubtoad5/seaweedfs-installer), the default of
**Script URL**:

| Blueprint | Installer |
|---|---|
| 1.2.1.0 | [`v1.3.0`](https://github.com/Chubtoad5/seaweedfs-installer/releases/tag/v1.3.0), checked against the release's `SHA256SUMS` |
| 1.2.0.0 | commit `530e0b4`, since tagged [`v1.0.0`](https://github.com/Chubtoad5/seaweedfs-installer/releases/tag/v1.0.0) |

In airgapped mode the installer comes from the offline package instead, so it is the
release that built the package.

## Prerequisites

This blueprint **must be deployed on top of an existing `edge-cloud-init` deployment** from the tme-tech-ops suite. Choose that deployment in **Deploy On**: it provides the VM and the SSH connection details (host, user and private key) through its capabilities. It must carry the labels:

- `csys-obj-type: environment`
- `solution: edge-cloud-init`

## Required Secrets

| Secret | Type | Description |
|--------|------|-------------|
| Registry Authentication Secret | `basic_auth_credentials` | Username and password for a local container registry. Required when using `install push` or `push` run tasks, or installing from a local registry in offline mode. |
| Offline Binary Configuration Secret | `binary_configuration` | URL, username, access token, and version of the offline archive binary. Required only when **Airgapped Mode** is enabled. |
| Upload URL Secret | `binary_configuration` | Points to the upload destination for the offline archive (e.g. `https://myfileserver.lab/upload_dir/`). Required only when **Upload save package** is enabled. |

The values in these secrets reach the VM single-quoted, so they can't contain a single quote (`'`).

For `install push` and `push`, the registry needs the projects `chrislusf` and `library`, plus `grafana` and `prom` when monitoring is on. A registry-tech-ops deployment's default projects include all four.

## Inputs

Text inputs are validated in the form; each input's description says what it accepts. Optional text inputs left blank get the installer's default.

### SeaweedFS Configuration

| Display Name | Input Key | Default | Description |
|---|---|---|---|
| Host FQDN | `host_fqdn` | `""` | Base FQDN for the host (e.g. `myhost.edge.lab`). Used to construct sub-domain FQDNs for each service. Caddy generates TLS certificates automatically per sub-domain. Leave blank to use `hostname.edge.lab`. |
| SeaweedFS Container Image | `swfs_image` | `chrislusf/seaweedfs:4.30` | Container image for SeaweedFS. The default is the version the installer pins; `latest` pulls whatever is newest on the day of the install. |
| Caddy Container Image | `caddy_image` | `caddy:2.11.3` | Container image for Caddy reverse proxy. Same as above. |
| SeaweedFS Username | `swfs_user` | `admin` | Username for SeaweedFS Admin UI, Filer, Master, SMB, and Grafana; also the Linux user for the SMB share. |
| SeaweedFS Password | `swfs_password` | `changeme` | Password for SeaweedFS Admin UI, Filer, Master, SMB, and Grafana. The installer writes it into its compose files, and the SeaweedFS image's entrypoint splits the Admin UI's at spaces and expands `*`, `?` and `[`, so it can't contain `'`, `$`, `"`, `\`, `#`, a space, `*`, `?`, `[`, a colon at the end, or control characters. |
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
| Default Filer Directory | `default_filer_dir_name` | `artifacts` | Default directory name on SeaweedFS Filer for artifacts; also the SMB share and NFS export name. |
| Artifacts to Download | `artifacts_to_download` | `""` | Artifact URLs, separated by spaces, to download with curl and upload to the SeaweedFS Filer. |
| S3 FQDN | `swfs_s3_fqdn` | `""` | FQDN for SeaweedFS S3 API. Defaults to `s3.<HOST_FQDN>` if left empty. |
| S3 Port | `swfs_s3_port` | `8333` | TCP port for SeaweedFS S3 API. |
| S3 User | `s3_user` | `admin` | S3 user name. Defaults to the SeaweedFS username if left empty. |
| Default S3 Bucket | `s3_bucket` | `charlie` | S3 buckets to create, separated by spaces. Blank gives the installer default, `charlie`. |
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
| Install Task | `run_arg` | `install` | Operation to perform. Options: `install` (from the internet), `install push` (push the images to a local registry, then install from it), `save` (create offline archive), `push` (push the images to a local registry and install nothing: pulled from the internet, or taken from a save archive extracted in the VM user's home directory). `install push` and `push` need Registry URL and the Registry Authentication Secret. Mutually exclusive with Airgapped Mode. |
| Script URL | `script_url` | *(installer release `v1.3.0`)* | URL of `install-seaweedfs`. A GitHub release asset is checked against that release's `SHA256SUMS`. Mutually exclusive with Airgapped Mode. |
| Airgapped Mode | `offline_mode` | `false` | Set to `true` to download and install from the specified offline package. |
| Offline Binary Configuration Secret | `offline_binary_secret` | *(optional)* | Secret containing the URL, username, access token, and version of the offline archive binary. Only shown when Airgapped Mode is enabled. |
| Registry Authentication Secret | `registry_secret` | *(optional)* | Secret containing username and password for a local container registry. Required for `install push` or `push` tasks, or offline installs from a local registry. |
| Registry URL | `registry_url` | `""` | Host and port of the local container registry, such as `myregistry.lab:5000`, with no `https://`. Ignored by `save`. |
| Upload save package | `upload_package` | `false` | Only for the `save` install task. Uploads the offline archive to a file server after creation. |
| Upload URL location | `upload_binary_secret` | *(optional)* | Binary configuration secret pointing to the upload destination. Only shown when Upload save package is enabled. |
| Log Output to hide | `hide_log_output` | `["stdout"]` | Controls which output streams are suppressed. Options: `stdout`, `stderr`, `both`. |
| Debug Logging | `debug` | `1` | Set to `1` to enable debug logging, `0` to disable. |

## Outputs

After a successful deployment the following capabilities are available:

| Output | Description |
|--------|-------------|
| `swfs_username` | SeaweedFS admin username, if Caddy accepted it (`N/A` otherwise) |
| `swfs_password` | SeaweedFS admin password, if Caddy accepted it (`N/A` otherwise) |
| `swfs_running` | `true` when `seaweed-mini` runs and Caddy answers |
| `swfs_admin_url` | SeaweedFS Admin UI URL (via IP address) |
| `swfs_filer_url` | SeaweedFS Filer browser URL (via IP address), ending in the Default Filer Directory |
| `swfs_master_url` | SeaweedFS Master console URL (via IP address) |
| `swfs_s3_url` | SeaweedFS S3 API URL (via IP address) |
| `swfs_grafana_url` | Grafana dashboard URL (N/A if monitoring disabled) |
| `offline_package_name` | Name of the offline archive (save operation only) |
| `offline_package_uploaded` | Whether the offline archive was uploaded |
| `offline_package_url` | URL where the offline archive was uploaded |

## Updating a Deployment

SeaweedFS is installed once, at install. Every input is locked and an update
never re-runs the installer, so an update with no change, or a move to a new
revision of this blueprint, leaves SeaweedFS, its data and its S3 keys as they
are. Image upgrades, the SMB/NFS/MQ/monitoring switches and stable S3 keys are
planned as update features.

- **Uninstalling** an `install` or `install push` deployment uninstalls
  SeaweedFS and deletes its data: objects, the Caddy CA that clients trust, and
  monitoring. Uninstalling a `save` or `push` deployment leaves SeaweedFS alone.
- **A reinstall or Heal** of `install_app` keeps SeaweedFS and its S3 keys: when
  SeaweedFS is installed and running, the installer isn't run again. On a VM
  that 1.2.0.0 installed, the installer there is `v1.0.0`, and a re-run would
  issue new S3 keys. Installer `v1.1.0` and later keep the keys, and `v1.3.0`
  leaves Samba and NFS running when a run changes nothing. If SeaweedFS is
  down, a Heal of `install_app` with **Force reinstall** ticked runs the
  installer that is on the VM. Without it, DAP's Heal skips `install_app`,
  which has no status check.
- **Updating a 1.2.0.0 deployment to 1.2.1.0** changes nothing on the VM: the
  installer copy it already has stays in place, and the deployment keeps the
  Script URL it was installed with.
- **Several deployments on one VM** (an `install` beside a `save` or `push`)
  share `~/install-seaweedfs`. The newest deployment's installer replaces it,
  and the older deployment's uninstall or Heal then runs that one.
- To resize the VM under SeaweedFS, update its **edge-cloudinit-linux**
  deployment with Force ticked (this deployment depends on it); SeaweedFS comes
  back after the VM restarts.
- If the VM gets a new IP address (for example a segment change), the URLs in
  the outputs and the certificates still show the old address until an
  IP-change repair feature exists.

See [CHANGELOG.md](CHANGELOG.md) for the changes in each version.
