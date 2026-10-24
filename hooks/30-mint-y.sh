#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Builds the Mint-Y theme and icon packs from source (upstream git) and
# installs them under /usr/share. See MINT-Y-ATTRIBUTION.txt for licenses.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

themes_url=https://github.com/linuxmint/mint-themes
icons_url=https://github.com/linuxmint/mint-y-icons
work="$(mktemp -d /tmp/mint-y.XXXXXX)"
trap 'rm -rf "$work"' EXIT

apt-get update
# git, make and python3 come from the profile or are tiny; sassc is the
# builder and is removed again afterwards.
apt-get install -y --no-install-recommends ca-certificates git make python3
build_dep=""
if apt-get install -y --no-install-recommends pysassc >/dev/null 2>&1; then
  build_dep=pysassc
else
  echo "pysassc package missing, trying python3-sass" >&2
  apt-get install -y --no-install-recommends python3-sass
  build_dep=python3-sass
fi

git clone --depth 1 "$icons_url" "$work/mint-y-icons"
git clone --depth 1 "$themes_url" "$work/mint-themes"
icons_rev="$(git -C "$work/mint-y-icons" rev-parse HEAD)"
themes_rev="$(git -C "$work/mint-themes" rev-parse HEAD)"

# Icons are shipped pre-rendered upstream.
mkdir -p /usr/share/icons
cp -a "$work/mint-y-icons/usr/share/icons/." /usr/share/icons/

# Themes: generate the gtk css with sass; fall back to the pre-generated
# files that upstream keeps in files/ if the generator fails.
mkdir -p /usr/share/themes
if (cd "$work/mint-themes" && make); then
  cp -a "$work/mint-themes/usr/share/themes/." /usr/share/themes/
else
  echo "WARNING: theme generation failed, using pre-generated upstream files" >&2
  cp -a "$work/mint-themes/files/usr/share/themes/." /usr/share/themes/
fi

# Attribution and upstream copyright notices (outside /usr/share/doc, which
# the slim hook prunes).
lic=/usr/share/licenses/pocketlinux-mint-y
mkdir -p "$lic"
install -m 0644 /tmp/pl/files/MINT-Y-ATTRIBUTION.txt "$lic/MINT-Y-ATTRIBUTION.txt"
cp "$work/mint-y-icons/debian/copyright" "$lic/mint-y-icons.copyright"
cp "$work/mint-themes/debian/copyright" "$lic/mint-themes.copyright"
printf 'mint-y-icons %s\nmint-themes %s\n' "$icons_rev" "$themes_rev" > "$lic/SOURCE-REVISIONS.txt"

# Defaults for Cinnamon (unknown keys only produce a warning).
mkdir -p /usr/share/glib-2.0/schemas
cat > /usr/share/glib-2.0/schemas/90_pocketlinux.gschema.override <<'OVR'
[org.cinnamon.desktop.interface]
gtk-theme='Mint-Y'
icon-theme='Mint-Y'

[org.cinnamon.theme]
name='Mint-Y'
OVR
glib-compile-schemas /usr/share/glib-2.0/schemas || echo "WARNING: glib-compile-schemas failed" >&2
gtk-update-icon-cache -q -f /usr/share/icons/Mint-Y 2>/dev/null || true

apt-get purge -y "$build_dep"
apt-get autoremove -y
