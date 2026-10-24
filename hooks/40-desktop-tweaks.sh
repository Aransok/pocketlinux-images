#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Desktop defaults that matter inside proot: no compositing, no session lockers.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
# shellcheck source=/dev/null
. /tmp/pl/env

case "${PL_DESKTOP}" in
  xfce)
    d=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml
    mkdir -p "$d"
    cat > "$d/xfwm4.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="off"/>
  </property>
</channel>
XML
    ;;
  cinnamon)
    # Cinnamon is run in its 2D (software) mode by start-desktop.
    mkdir -p /etc/profile.d
    printf 'export CINNAMON_2D=true\n' > /etc/profile.d/pocketlinux-cinnamon.sh
    ;;
  none)
    ;;
esac

# Firefox: the content sandbox needs namespaces that proot cannot provide.
if command -v firefox >/dev/null 2>&1 || command -v firefox-esr >/dev/null 2>&1; then
  printf 'export MOZ_DISABLE_CONTENT_SANDBOX=1\nexport MOZ_DISABLE_RDD_SANDBOX=1\n' > /etc/profile.d/pocketlinux-firefox.sh
fi

# Do not autostart screen lockers: no logind, nothing to lock against.
for f in light-locker xfce4-screensaver xscreensaver cinnamon-screensaver; do
  [ -f "/etc/xdg/autostart/$f.desktop" ] && echo 'Hidden=true' >> "/etc/xdg/autostart/$f.desktop"
done
exit 0
