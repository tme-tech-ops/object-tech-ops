# Changelog for object-tech-ops

All notable changes to this blueprint are recorded here. The version is also
the catalog revision to upload the blueprint as.

## 1.2.1.0 - 2026-11-11

Moves to seaweedfs-installer `v1.3.0` and fixes what was wrong in 1.2.0.0.
Updating a 1.2.0.0 deployment to it changes nothing on the VM.

- Changed: `script_url` defaults to the installer's `v1.3.0` release asset
  instead of commit `530e0b4`. `env_precheck` checks a GitHub release asset
  against that release's `SHA256SUMS`, keeps a file that doesn't match off the
  VM, and no longer downloads with `curl -k`. With `v1.3.0`, a re-run keeps the
  S3 keys, doesn't restart Caddy, and leaves Samba and NFS running when nothing
  changed. The installer exits 0 only once Caddy serves, records its version
  in `.install-state`, keeps its compose files private, and pins the helper
  scripts it downloads to releases.
- Fixed: text values reached the scripts through an unquoted shell `export`,
  so `$`, backticks, `\` and spaces in a password or other value were changed or
  broke the command. They are now single-quoted. The SeaweedFS password, user
  names, host names, Filer directory, buckets, cluster name, artifact URLs,
  registry URL and images are validated, and none accepts a single quote.
- Fixed: the SeaweedFS password goes into the installer's compose files, where
  `$`, `"`, `\`, `#` and a colon followed by a space or at the end change or
  cut it. The form refuses those. It also refuses a space, `*`, `?` and `[`:
  the SeaweedFS image's entrypoint passes the Admin UI password on unquoted, so
  it is split at spaces (the Admin UI then takes only the first word) and
  globbed.
- Fixed: the registry password travelled inside one command string, stored in
  `env_precheck`'s runtime properties (`install_cmd`), and a space or `*` in it
  split or expanded it. `install_app` now passes the registry user and
  password to the installer as separate, quoted arguments, and nothing stores
  them.
- Fixed: with Registry URL set, a `save` deployment failed, because the
  installer refuses `-registry` with `save`. `-registry` now goes only to
  `install`, `install push` and `push`, and `install push` or `push` without a
  registry stops with a reason.
- Fixed: the scripts left their settings, passwords included, in env files on
  the VM. Each script now deletes its env file first.
- Fixed: a failed check or install was retried for 15 minutes or more,
  re-running the installer each time. They now fail at once (exit code 1).
- Fixed: `env_postcheck` only checked that `seaweed-mini` ran, then published
  the inputs' user and password, with default ports in the URLs and no Filer
  directory. It now checks that Caddy answers on the Filer's
  `/<dir>/`, checks the credentials there, and publishes only credentials
  Caddy accepted. The URLs carry the deployment's ports, and the Filer URL ends
  in its directory.
- Fixed: a cleared optional text input could reach the installer as `None`;
  it now arrives empty, and the installer uses its default.
- Changed: online `install`, `install push` and `save` set
  `SWFS_FORCE_ONLINE=true`, so a package left in the home directory by an
  earlier `save` deployment can't switch them to the offline package.
- Changed: image defaults are `chrislusf/seaweedfs:4.30` and `caddy:2.11.3`,
  the versions the installer pins, instead of `latest`, which is still allowed.
- Fixed: texts. The README listed `vm_deployment_id` and SSH key inputs that
  don't exist, and said a re-run always issues new S3 keys. The `push` task
  doesn't push only saved images: online it pulls them from the internet. The
  registry projects it needs are now listed.
- Lint: the remaining findings are the plain-text `swfs_password` input, as in
  1.2.0.0. The linter no longer flags its uses in `definitions.yaml`, because
  they are wrapped in quotes; the input itself is still flagged.

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
