# Mint-Y attribution

The `ubuntu-cinnamon` profile builds the Mint-Y GTK theme family and the
Mint-Y icon theme family from source inside the image (hook
`hooks/30-mint-y.sh`). Nothing from those projects is stored in this
repository; the hook clones them at build time.

Sources:

- https://github.com/linuxmint/mint-themes (GPL-3.0-or-later)
- https://github.com/linuxmint/mint-y-icons (GPL-3.0-or-later for scripts and
  general files, CC BY-SA 4.0 for the artwork under `usr/share/icons`,
  copyright Sam Hewitt and Alexey Varfolomeev, derived from Paper and Moka)

The image carries the same notice at
`/usr/share/licenses/pocketlinux-mint-y/MINT-Y-ATTRIBUTION.txt`, together
with the upstream copyright files and the exact source revisions used.
The text of that notice is kept in `hooks/files/MINT-Y-ATTRIBUTION.txt`.

CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/legalcode

The Linux Mint name and logo are trademarks of their owners. This project is
not affiliated with or endorsed by the Linux Mint project.
