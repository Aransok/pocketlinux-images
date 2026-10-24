#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Installs start-desktop and pl-doctor.
set -euo pipefail
install -D -m 0755 /tmp/pl/files/start-desktop /usr/local/bin/start-desktop
install -D -m 0755 /tmp/pl/files/pl-doctor /usr/local/bin/pl-doctor
