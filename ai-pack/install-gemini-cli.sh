#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs the Gemini CLI (@google/gemini-cli) with npm.
# Falls back to npm ignore-scripts mode if the normal install fails.
# Needs Node 20 or newer. Set FORCE=1 to reinstall.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-gemini-cli

if pl_have gemini && [ "${FORCE:-0}" != "1" ]; then
  pl_log "gemini already installed: $(gemini --version 2>/dev/null || echo unknown)"
else
  pl_ensure_node 20
  if ! pl_npm_global @google/gemini-cli; then
    pl_warn "normal install failed, retrying with the ignore-scripts option"
    pl_npm_global @google/gemini-cli --ignore-scripts
  fi
fi

pl_have gemini || pl_die "gemini not found on PATH after install"
pl_log "installed: $(gemini --version 2>/dev/null || echo unknown)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Run: gemini
  3. Sign in with your Google account, or set GEMINI_API_KEY.
NEXT
