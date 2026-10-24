#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs n8n (workflow automation) with npm. Needs Node 20 or newer.
# Set FORCE=1 to reinstall or update.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-n8n

if pl_have n8n && [ "${FORCE:-0}" != "1" ]; then
  pl_log "n8n already installed: $(n8n --version 2>/dev/null || echo unknown)"
else
  pl_apt_install build-essential python3 git ca-certificates
  pl_ensure_node 20
  pl_npm_global n8n
fi

pl_have n8n || pl_die "n8n not found on PATH after install"
pl_log "installed: $(n8n --version 2>/dev/null || echo unknown)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Start it: N8N_SECURE_COOKIE=false n8n start
     (the cookie flag is needed because the local page uses plain http)
  3. Open http://127.0.0.1:5678 in the phone browser and create the owner account.
Data lives in ~/.n8n. Expect it to use several hundred MB of RAM.
NEXT
