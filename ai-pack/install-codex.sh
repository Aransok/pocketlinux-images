#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs the OpenAI Codex CLI (@openai/codex) with npm.
# Falls back to npm ignore-scripts mode if the normal install fails.
# Set FORCE=1 to reinstall.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-codex

if pl_have codex && [ "${FORCE:-0}" != "1" ]; then
  pl_log "codex already installed: $(codex --version 2>/dev/null || echo unknown)"
else
  pl_ensure_node 20
  if ! pl_npm_global @openai/codex; then
    pl_warn "normal install failed, retrying with the ignore-scripts option"
    pl_npm_global @openai/codex --ignore-scripts
  fi
fi

pl_have codex || pl_die "codex not found on PATH after install"
pl_log "installed: $(codex --version 2>/dev/null || echo unknown)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Run: codex
  3. Sign in with your ChatGPT account, or set OPENAI_API_KEY.
If you used the ignore-scripts fallback and codex fails to start, the
platform binary was not set up; reinstall with FORCE=1 on a better connection.
NEXT
