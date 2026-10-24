#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Generate manifest.json from the tarballs in dist/.

usage: make-manifest.py [--dist DIR] [--profiles DIR] [--out FILE]

Environment:
  PL_BASE_URL   base url of the download host
                (default https://images.pocketlinux.app/)
"""
import argparse
import datetime
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "build"))
import plprofile  # noqa: E402

SUFFIX = "-arm64.tar.xz"


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_profiles(directory):
    out = {}
    for fn in sorted(os.listdir(directory)):
        if fn.endswith(".yaml"):
            data = plprofile.load(os.path.join(directory, fn))
            out[data["name"]] = data
    return out


def match(filename, profiles):
    """Return (profile, version) for dist file names like name-version-arm64.tar.xz.

    Profile names contain hyphens and so can versions, so match by known
    profile name, longest name first.
    """
    if not filename.endswith(SUFFIX):
        return None
    stem = filename[: -len(SUFFIX)]
    for name in sorted(profiles, key=len, reverse=True):
        if stem.startswith(name + "-") and len(stem) > len(name) + 1:
            return profiles[name], stem[len(name) + 1:]
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dist", default=os.path.join(ROOT, "dist"))
    ap.add_argument("--profiles", default=os.path.join(ROOT, "profiles"))
    ap.add_argument("--out", default=None, help="default: <dist>/manifest.json")
    args = ap.parse_args()

    base_url = os.environ.get("PL_BASE_URL", "https://images.pocketlinux.app/")
    if not base_url.endswith("/"):
        base_url += "/"
    out_path = args.out or os.path.join(args.dist, "manifest.json")

    profiles = load_profiles(args.profiles)
    images = []
    for fn in sorted(os.listdir(args.dist)):
        found = match(fn, profiles)
        if not found:
            continue
        prof, version = found
        path = os.path.join(args.dist, fn)
        digest = sha256_of(path)
        sum_file = path + ".sha256"
        if os.path.exists(sum_file):
            with open(sum_file, encoding="utf-8") as fh:
                recorded = fh.read().split()[0]
            if recorded != digest:
                sys.exit("checksum mismatch for %s" % fn)
        images.append({
            "name": prof["name"],
            "display_name": prof["display_name"],
            "version": version,
            "url": base_url + fn,
            "sha256": digest,
            "size": os.path.getsize(path),
            "desktop": prof["desktop"],
            "min_ram_mb": int(prof["min_ram_mb"]),
            "base_url": base_url,
        })
    if not images:
        sys.exit("no image tarballs found in %s" % args.dist)

    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if epoch:
        stamp = datetime.datetime.fromtimestamp(int(epoch), datetime.timezone.utc)
    else:
        stamp = datetime.datetime.now(datetime.timezone.utc)
    manifest = {
        "schema": 1,
        "generated": stamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "images": images,
    }
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")
    print("wrote %s (%d images)" % (out_path, len(images)))


if __name__ == "__main__":
    main()
