#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Installs start-desktop, pl-doctor and pl-x11.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
install -D -m 0755 /tmp/pl/files/start-desktop /usr/local/bin/start-desktop
install -D -m 0755 /tmp/pl/files/pl-doctor /usr/local/bin/pl-doctor
# pl-x11 starts the X server of Pocket Linux Display (see the pocketlinux-x11 repository).
# Keep this copy identical to scripts/pl-x11 there.
install -D -m 0755 /tmp/pl/files/pl-x11 /usr/local/bin/pl-x11
