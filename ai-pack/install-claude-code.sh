#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs Claude Code with the official installer.
# Works inside the proot Debian or Ubuntu images (glibc). It does NOT work in
# plain Termux, because the native binary is built for glibc, not Android's libc.
# Set FORCE=1 to reinstall or update.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-claude-code

if pl_have claude && [ "${FORCE:-0}" != "1" ]; then
  pl_log "claude already installed: $(claude --version 2>/dev/null || echo unknown). Set FORCE=1 to reinstall."
else
  pl_apt_install curl ca-certificates
  pl_log "running the official installer"
  curl -fsSL https://claude.ai/install.sh | bash
fi
pl_path_line "$HOME/.local/bin"

pl_have claude || pl_die "claude not found on PATH after install"
pl_log "installed: $(claude --version 2>/dev/null || echo unknown)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Go to your project folder and run: claude
  3. Sign in when asked (browser login, or set ANTHROPIC_API_KEY).
Note: this works in the proot images, not in plain Termux.
NEXT
