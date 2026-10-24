#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Installs start-desktop and pl-doctor.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
install -D -m 0755 /tmp/pl/files/start-desktop /usr/local/bin/start-desktop
install -D -m 0755 /tmp/pl/files/pl-doctor /usr/local/bin/pl-doctor
