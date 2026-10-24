# pocketlinux-images

Reproducible ARM64 Linux root filesystem images for the Pocket Linux Android
app. The images run under proot: no root, no systemd, no init. Every image is a
single `.tar.xz` that the app downloads, verifies and unpacks.

This repository holds the build scripts, the image profiles, the manifest
generator and the publishing scripts. It does not hold any distribution files.

## Images

Display names are what users see in the app. The profile id is internal.

- `test-minimal`: display name "Test Minimal". Debian trixie, no desktop,
  about 300 MB unpacked. Used by the phase 0 spike.
- `debian-xfce`: display name "Desktop Light". Debian trixie with XFCE, a
  browser and a dev stack. About 2 GB unpacked.
- `ubuntu-cinnamon`: display name "Desktop Classic". Ubuntu noble arm64 with
  Cinnamon, the Mint-Y theme and icons built from source, a browser and the
  same dev stack.

## Layout

- `build/build-image.sh`: builds one profile into `dist/`.
- `build/plprofile.py`: tiny profile parser, standard library only.
- `build/verify-image.sh`: sanity checks on a built tarball.
- `profiles/*.yaml`: one file per image.
- `hooks/*.sh`: scripts that run inside the new root filesystem, in the order
  the profile lists them. `hooks/files/` holds files they install.
- `manifest/make-manifest.py`: writes `dist/manifest.json`.
- `publish/upload-r2.sh`, `publish/github-release.sh`: publishing.
- `ai-pack/`: install scripts for AI tools, to run inside an image later.
- `.github/workflows/build-images.yml`: CI.

## Building locally

### On an arm64 machine

Use an arm64 Debian or Ubuntu host (an arm64 VM, a cloud arm64 instance, or an
arm64 Linux laptop). Install the tools:

    sudo apt install mmdebstrap debian-archive-keyring ubuntu-keyring xz-utils python3

Build:

    sudo build/build-image.sh test-minimal

The result is `dist/test-minimal-<version>-arm64.tar.xz` plus a `.sha256` file.
Compression is `xz -9` with all cores. The version comes from `IMAGE_VERSION`,
else the latest git tag, else the `version` in the profile.

Without root, mmdebstrap can use user namespaces (unshare mode). Some
distributions restrict those; use sudo if you see a namespace error.

### On an x86_64 machine with qemu

    sudo apt install mmdebstrap qemu-user-static binfmt-support debian-archive-keyring ubuntu-keyring xz-utils python3
    sudo build/build-image.sh debian-xfce

It works but is slow, because every package script runs under emulation. If
mmdebstrap is not installed the script falls back to `debootstrap`, which
needs root and ignores `install_recommends`. Force a builder with
`PL_BUILDER=mmdebstrap` or `PL_BUILDER=debootstrap`.

### Useful environment variables

- `IMAGE_VERSION`: version in the output name.
- `DIST_DIR`: output directory (default `dist/`).
- `PL_APT_CACHE`: directory used to cache downloaded packages between builds.
- `PL_MIRROR`: use another package mirror.
- `PL_STRICT=1`: make optional hooks (the Ubuntu browser hook) fatal.
- `SOURCE_DATE_EPOCH`: timestamp clamp. Defaults to the last commit time.

Reproducibility note: mmdebstrap and the timestamp clamp make package
contents deterministic for a given mirror snapshot. Hooks that fetch from git
or a PPA at build time (Mint-Y, the Ubuntu browser) follow upstream, so
bit-identical output needs the same upstream state. The exact Mint-Y revisions
are recorded in the image.

## Profile format

A profile is a small YAML file. The parser supports only what is shown here
(scalars, one level lists, comments), so no extra tools are needed.

    name: test-minimal            # must match the file name
    display_name: Test Minimal    # shown in the app, letters and digits only
    version: 0.1.0                # fallback version
    base: debian-trixie           # debian-trixie or ubuntu-noble
    arch: arm64                   # only arm64
    desktop: none                 # xfce, cinnamon or none
    min_ram_mb: 512               # advertised in the manifest
    install_recommends: false     # apt recommends, default false
    max_uncompressed_mb: 300      # optional, build warns above this
    packages:
      - bash
      - python3
    hooks:                        # run in this order, from hooks/<name>.sh
      - 10-base
      - 20-scripts
      - 90-slim

Display names must not contain distribution names. The profile validator
rejects them.

### Hooks

Hooks run inside the new root filesystem. They source `/tmp/pl/env`, which
exports `PL_NAME`, `PL_DISPLAY_NAME`, `PL_VERSION`, `PL_BASE`, `PL_ARCH`,
`PL_DESKTOP`. Common hooks:

- `10-base`: policy-rc.d so nothing starts daemons, apt settings for proot,
  locale `en_US.UTF-8`, resolv.conf placeholder, user `linux` (uid 1000, sudo
  without password), default login stays root, `/etc/pocketlinux/release`.
- `20-scripts`: installs `start-desktop` and `pl-doctor` into `/usr/local/bin`.
- `30-mint-y`: builds Mint-Y themes and icons from upstream git.
- `35-firefox-deb`: Ubuntu only, real browser deb from the Mozilla team PPA,
  because the archive package is a snap shim that cannot run without systemd.
- `40-desktop-tweaks`: compositing off for XFCE, 2D mode for Cinnamon,
  browser sandbox switches for proot, no screen lockers.
- `90-slim`: strips docs, man pages, non-English locale data and apt caches.
  Copyright files are kept. Run `apt update` once before the first install.

### Scripts inside the image

- `start-desktop`: waits for the X server, starts a D-Bus session, sets
  `DISPLAY=:0` and `PULSE_SERVER=tcp:127.0.0.1:4713` (both can be overridden),
  then starts the profile's session with fallbacks. Logs to
  `/var/log/pocketlinux-desktop.log`. `PL_SESSION_CMD` overrides the first
  command tried.
- `pl-doctor`: prints kernel, architecture, free RAM, GPU related environment
  variables and whether the display and audio servers are reachable.

## GPU acceleration

Nothing about the GPU is hard coded in the images. The app sets the
environment when it launches a session, for example:

- Adreno with Turnip and Zink: `MESA_LOADER_DRIVER_OVERRIDE=zink` and
  `GALLIUM_DRIVER=zink`
- virgl: `GALLIUM_DRIVER=virpipe`
- software rendering: `LIBGL_ALWAYS_SOFTWARE=1`

The images ship the Mesa DRI and Vulkan driver packages and `mesa-utils`
(`glxinfo`), and `pl-doctor` shows what the session actually received.

## How the app consumes manifest.json

`manifest/make-manifest.py` scans `dist/` and writes `dist/manifest.json`:

    {
      "schema": 1,
      "generated": "2026-01-01T00:00:00Z",
      "images": [
        {
          "name": "debian-xfce",
          "display_name": "Desktop Light",
          "version": "0.1.0",
          "url": "https://images.pocketlinux.app/debian-xfce-0.1.0-arm64.tar.xz",
          "sha256": "...",
          "size": 734003200,
          "desktop": "xfce",
          "min_ram_mb": 3072,
          "base_url": "https://images.pocketlinux.app/"
        }
      ]
    }

`size` is the compressed download size in bytes. The app fetches
`<base_url>manifest.json`, lists images by `display_name`, hides those whose
`min_ram_mb` exceeds the device RAM, downloads `url`, checks `sha256`, then
unpacks the tarball into its proot root. Change the host with the environment
variable `PL_BASE_URL` when generating the manifest.

## Publishing

Cloudflare R2 is the primary host, GitHub Releases is a mirror.

    export R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=...
    python3 manifest/make-manifest.py
    publish/upload-r2.sh                 # bucket pocketlinux-images, override with R2_BUCKET
    publish/github-release.sh v0.1.0     # needs gh, creates the release if missing

Tarballs are uploaded first and never overwritten, the manifest goes last.
Set `DRY_RUN=1` to test the R2 upload.

## CI

`.github/workflows/build-images.yml` builds on `ubuntu-24.04-arm` runners, so
no emulation is needed. Pull requests and pushes to main build only
`test-minimal`. Tags `v*` and manual runs build every profile. On a tag the
workflow creates a GitHub Release with all assets and `manifest.json`, and
uploads to R2 when the secrets `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID` and
`R2_SECRET_ACCESS_KEY` exist. Downloaded packages are cached per profile.

## AI tools pack

`ai-pack/` has install scripts for use inside a running image: Claude Code,
aider, Codex CLI, Gemini CLI, code-server and n8n. Each one is idempotent,
logs to `~/.pocketlinux/logs/`, and prints next steps. The Claude Code
installer works in the proot Debian and Ubuntu images but not in plain Termux.
These scripts are MIT licensed (see `ai-pack/LICENSE`).

## Licensing

- This repository: GNU GPL version 3 (see `LICENSE`), except `ai-pack/`,
  which is MIT.
- The images contain software from many projects. Each package keeps its own
  license, and the copyright files under `/usr/share/doc/<package>/copyright`
  are kept in every image. Source for packages is available from the
  respective distribution archives.
- Mint-Y themes and icons (Desktop Classic image): built from
  github.com/linuxmint/mint-themes and github.com/linuxmint/mint-y-icons.
  Scripts and themes are GPL-3.0-or-later, the icon artwork is CC BY-SA 4.0.
  See `ATTRIBUTION-MINT-Y.md`; the notice is also inside the image at
  `/usr/share/licenses/pocketlinux-mint-y/`.

## Trademarks

Debian, Ubuntu, Linux Mint, Firefox, Cinnamon, XFCE and other names are
trademarks of their owners. This project is not affiliated with or endorsed by
any of them. Distribution names appear only as internal profile ids and
package sources, never as image display names.
