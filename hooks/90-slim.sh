#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Strips docs, man pages, extra locales and apt caches to cut size.
# Copyright files are kept on purpose (license compliance).
set -euo pipefail

# Keep future installs slim too.
mkdir -p /etc/dpkg/dpkg.cfg.d
cat > /etc/dpkg/dpkg.cfg.d/90-pocketlinux-slim <<'CONF'
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
path-exclude=/usr/share/man/*
path-exclude=/usr/share/groff/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/lintian/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en*
path-include=/usr/share/locale/locale.alias
CONF

# Docs: remove everything except copyright files, then empty dirs and dead links.
if [ -d /usr/share/doc ]; then
  find /usr/share/doc -depth -type f ! -name copyright -delete
  find /usr/share/doc -xtype l -delete
  find /usr/share/doc -depth -type d -empty -delete
fi
rm -rf /usr/share/man/* /usr/share/groff /usr/share/info /usr/share/lintian /usr/share/linda /usr/share/doc-base

# Translations: keep English only.
if [ -d /usr/share/locale ]; then
  find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name locale.alias -exec rm -rf {} +
fi

# apt and dpkg leftovers.
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/debconf/*-old \
  /var/lib/dpkg/*-old /var/log/apt /var/log/alternatives.log /var/log/dpkg.log \
  /var/log/bootstrap.log /root/.cache
mkdir -p /var/lib/apt/lists/partial
find /tmp -mindepth 1 -maxdepth 1 ! -name pl -exec rm -rf {} +
