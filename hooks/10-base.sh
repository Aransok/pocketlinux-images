#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Common base setup, runs inside the new rootfs (chroot).
# Nothing here may require a running init system: proot has no systemd.
set -euo pipefail
# shellcheck source=/dev/null
. /tmp/pl/env
export DEBIAN_FRONTEND=noninteractive

# 1. Never start daemons from package scripts (no init, no systemd).
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d

# 2. apt tweaks for proot: the _apt sandbox user cannot switch groups there.
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99pocketlinux <<'CONF'
APT::Sandbox::User "root";
Dpkg::Use-Pty "0";
Acquire::Languages "none";
CONF

# 3. Locale en_US.UTF-8
if ! command -v locale-gen >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends locales
fi
sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
printf 'LANG=en_US.UTF-8\n' > /etc/default/locale

# 4. resolv.conf placeholder. The app rewrites it at launch.
rm -f /etc/resolv.conf
printf '# placeholder written at image build time, replaced by the app at launch\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf

# 5. hosts
printf '127.0.0.1 localhost\n::1 localhost ip6-localhost ip6-loopback\n' > /etc/hosts

# 6. User "linux" (uid 1000) with sudo. Default login stays root.
if getent passwd 1000 >/dev/null 2>&1 && [ "$(getent passwd 1000 | cut -d: -f1)" != "linux" ]; then
  old="$(getent passwd 1000 | cut -d: -f1)"
  usermod -l linux -d /home/linux -m "$old"
  groupmod -n linux "$old" 2>/dev/null || true
elif ! getent passwd linux >/dev/null 2>&1; then
  useradd -m -u 1000 -s /bin/bash linux
fi
getent group sudo >/dev/null 2>&1 || groupadd sudo
usermod -aG sudo linux
for g in audio video; do
  getent group "$g" >/dev/null 2>&1 && usermod -aG "$g" linux
done
passwd -l linux >/dev/null 2>&1 || true
passwd -l root >/dev/null 2>&1 || true
mkdir -p /etc/sudoers.d
printf 'linux ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-pocketlinux
chmod 0440 /etc/sudoers.d/90-pocketlinux

# 7. Release info read by the app and by pl-doctor.
mkdir -p /etc/pocketlinux
cat > /etc/pocketlinux/release <<REL
NAME="${PL_DISPLAY_NAME}"
ID=${PL_NAME}
VERSION=${PL_VERSION}
DESKTOP=${PL_DESKTOP}
BASE=${PL_BASE}
ARCH=${PL_ARCH}
REL
printf '%s\n' "${PL_DESKTOP}" > /etc/pocketlinux/desktop
printf 'root\n' > /etc/pocketlinux/default-user

# 8. machine-id is created on first use, not baked into the image.
: > /etc/machine-id
mkdir -p /var/lib/dbus
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# 9. Shell defaults for both users.
cat > /etc/profile.d/pocketlinux.sh <<'PROF'
export LANG=en_US.UTF-8
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
[ -d "$XDG_RUNTIME_DIR" ] || { mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"; } 2>/dev/null || true
PROF
