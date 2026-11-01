# Changelog for object-tech-ops

All notable changes to this blueprint are recorded here. The version is also
the catalog revision to upload the blueprint as.

## 1.2.0.0 - 2026-10-31

Safe deployment updates (Day-2). Works on a VM from edge-cloudinit-linux
1.0.0 or 1.2.0.0.

- Fixed: an update could delete the object store. `install_app`'s `stop` ran
  `install-seaweedfs uninstall`, and an update's automatic reinstall, a
  reinstall list or Heal runs `stop`. SeaweedFS and its data are now removed
  only when the deployment is uninstalled, and only for an `install` or
  `install push` deployment.
- Fixed: every run of the installer issued new random S3 keys, locking out
  existing S3 clients. An update no longer runs the installer, and a
  reinstall or Heal of `install_app` keeps an installed, running SeaweedFS
  instead of re-running it.
- Changed: an update never re-runs the installer. `env_precheck`,
  `install_app` and `env_postcheck` report no drift and have no update
  operation. Changed settings (images, artifacts) were dropped before they
  reached the installer anyway; every input is now locked (see "Updating a
  Deployment" in the README).
- Fixed: in airgapped mode the Install Task is hidden and arrived empty; it
  now runs `install`.
- Fixed: the install command was logged with the registry password, and the
  offline download with its password. The registry password was also passed
  unquoted.
- Changed: `script_url` defaults to a pinned installer commit instead of the
  installer's `main` branch.
- Changed: line endings are LF (they were CRLF; the fabric plugin stripped
  them before running the scripts, so nothing changes at run time).
- Changed: plugin imports moved to the entry file (fabric only; edge and
  utilities were unused); unused hidden inputs removed; every constraint has
  an error message; the port and debug inputs are validated; the version label
  is corrected. Lint: the remaining findings are the plain-text
  `swfs_password` input, left for the credentials change (secret inputs) that
  follows this release.

## 1.1.5.0

Release restructure and pinning supported plugins for DAP 2.0.0.1 / DDPC 4.2.0.0 -
untested (2026-11-01).

- On branch `ddpc-4.2.0.0-snapshot`, not on `main`: the 1.2.0.0 code for DAP
  2.0.0.1 with DDPC 4.2.0.0, not tested on that platform.
- Imports only the fabric-plugin, unchanged (no pin needed).
- Tags are now blueprint versions. Each has a GitHub release named after the DAP
  and DDPC versions it was tested on, with upload-ready zips.

## 1.0.0

Catalog revision 1.0.0, before this changelog.
