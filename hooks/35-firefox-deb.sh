#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ubuntu noble ships firefox as a snap shim that cannot run without systemd.
# Install the real deb from the Mozilla team PPA and pin it above the archive.
# A failure here is reported loudly but does not fail the build unless
# PL_STRICT=1 is set in the environment of build-image.sh.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

fingerprint=0AB215679C571D1C8325275B9BDB3D89CE49EC21
keyring=/etc/apt/keyrings/mozillateam.gpg

install_firefox() {
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl gnupg
  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${fingerprint}" \
    | gpg --dearmor > "$keyring"
  printf 'deb [signed-by=%s] https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu noble main\n' \
    "$keyring" > /etc/apt/sources.list.d/mozillateam.list
  cat > /etc/apt/preferences.d/mozillateam <<'PIN'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
PIN
  apt-get update
  apt-get install -y --no-install-recommends firefox
}

if ! install_firefox; then
  echo "WARNING: could not install firefox from the Mozilla team PPA" >&2
  if [ "${PL_STRICT:-0}" = "1" ]; then
    exit 1
  fi
fi
