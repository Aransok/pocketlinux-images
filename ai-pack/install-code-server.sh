#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Installs code-server (VS Code in the browser) with the official standalone
# installer into ~/.local. Set FORCE=1 to reinstall or update.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"
pl_init install-code-server

pl_path_line "$HOME/.local/bin"
if pl_have code-server && [ "${FORCE:-0}" != "1" ]; then
  pl_log "code-server already installed: $(code-server --version 2>/dev/null | head -n1)"
else
  pl_apt_install curl ca-certificates
  curl -fsSL https://code-server.dev/install.sh | sh -s -- --method standalone
fi

pl_have code-server || pl_die "code-server not found on PATH after install"
pl_log "installed: $(code-server --version 2>/dev/null | head -n1)"
cat <<'NEXT'

Next steps
  1. Open a new shell, or run: source ~/.bashrc
  2. Start it: code-server --bind-addr 127.0.0.1:8080
  3. Open http://127.0.0.1:8080 in the phone browser.
  4. The password is in ~/.config/code-server/config.yaml
Keep the bind address on 127.0.0.1 unless you know why you need more.
NEXT
