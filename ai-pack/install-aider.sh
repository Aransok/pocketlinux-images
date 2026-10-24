#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs aider (aider-chat) with pipx. Set FORCE=1 to reinstall.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-aider

pl_apt_install python3 python3-venv python3-pip pipx git
pipx ensurepath >/dev/null 2>&1 || true
pl_path_line "$HOME/.local/bin"

if pl_have aider && [ "${FORCE:-0}" != "1" ]; then
  pl_log "aider already installed: $(aider --version 2>/dev/null || echo unknown)"
else
  if ! pipx install --force aider-chat; then
    # aider-chat can lag behind the newest system python; the aider-install
    # helper brings its own python 3.12 through uv.
    pl_warn "pipx install failed, trying the aider-install helper"
    pipx install --force aider-install
    aider-install
  fi
fi

pl_have aider || pl_die "aider not found on PATH after install"
pl_log "installed: $(aider --version 2>/dev/null || echo unknown)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Set a provider key, for example: export ANTHROPIC_API_KEY=...
  3. In a git repository run: aider
NEXT
