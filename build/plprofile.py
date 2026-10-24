#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Tiny parser for the restricted YAML subset used by profiles/*.yaml.

Supported syntax:
  key: value            scalar (optionally quoted)
  key:                  list, followed by indented "- item" lines
    - item
  # comment             full line or trailing comment (preceded by a space)

No third party modules are needed. Use `--shell` to print the profile as
shell variable assignments that build-image.sh evals.
"""
import re
import shlex
import sys

SCALARS = ("name", "display_name", "base", "arch", "desktop", "min_ram_mb",
           "install_recommends", "max_uncompressed_mb", "version")
LISTS = ("packages", "hooks")
DESKTOPS = ("xfce", "cinnamon", "none")
BASES = ("debian-trixie", "ubuntu-noble")
FORBIDDEN_DISPLAY = re.compile(r"ubuntu|debian|mint", re.IGNORECASE)
PKG_RE = re.compile(r"^[a-z0-9][a-z0-9+.:=_-]*$")
HOOK_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


class ProfileError(Exception):
    pass


def _strip_comment(line):
    out = []
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            break
        out.append(ch)
    return "".join(out).rstrip()


def _unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse(text):
    data = {}
    current = None
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = _strip_comment(raw)
        if not line.strip():
            continue
        stripped = line.strip()
        if stripped.startswith("- "):
            if current is None:
                raise ProfileError("line %d: list item without a key" % lineno)
            data[current].append(_unquote(stripped[2:]))
            continue
        if line[0] in " \t":
            raise ProfileError("line %d: unexpected indentation" % lineno)
        m = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if not m:
            raise ProfileError("line %d: cannot parse %r" % (lineno, raw))
        key, value = m.group(1), m.group(2)
        if key in data:
            raise ProfileError("line %d: duplicate key %s" % (lineno, key))
        if value == "":
            data[key] = []
            current = key
        else:
            data[key] = _unquote(value)
            current = None
    return data


def validate(data):
    for key in data:
        if key not in SCALARS and key not in LISTS:
            raise ProfileError("unknown key: %s" % key)
    for key in ("name", "display_name", "base", "arch", "desktop",
                "min_ram_mb", "packages", "hooks"):
        if key not in data:
            raise ProfileError("missing key: %s" % key)
    if not NAME_RE.match(data["name"]):
        raise ProfileError("bad name: %s" % data["name"])
    if data["base"] not in BASES:
        raise ProfileError("base must be one of %s" % ", ".join(BASES))
    if data["arch"] != "arm64":
        raise ProfileError("arch must be arm64")
    if data["desktop"] not in DESKTOPS:
        raise ProfileError("desktop must be one of %s" % ", ".join(DESKTOPS))
    if not re.match(r"^[A-Za-z0-9 ]+$", data["display_name"]):
        raise ProfileError("display_name may only hold letters, digits, spaces")
    if FORBIDDEN_DISPLAY.search(data["display_name"]):
        raise ProfileError("display_name must not contain distro names")
    if not data["min_ram_mb"].isdigit():
        raise ProfileError("min_ram_mb must be an integer")
    rec = data.get("install_recommends", "false")
    if rec not in ("true", "false"):
        raise ProfileError("install_recommends must be true or false")
    if "max_uncompressed_mb" in data and not data["max_uncompressed_mb"].isdigit():
        raise ProfileError("max_uncompressed_mb must be an integer")
    if not data["packages"]:
        raise ProfileError("packages list is empty")
    for pkg in data["packages"]:
        if not PKG_RE.match(pkg):
            raise ProfileError("bad package name: %s" % pkg)
    for hook in data["hooks"]:
        if not HOOK_RE.match(hook):
            raise ProfileError("bad hook name: %s" % hook)
    return data


def load(path):
    with open(path, encoding="utf-8") as fh:
        return validate(parse(fh.read()))


def as_shell(data):
    pairs = {
        "PL_NAME": data["name"],
        "PL_DISPLAY_NAME": data["display_name"],
        "PL_BASE": data["base"],
        "PL_ARCH": data["arch"],
        "PL_DESKTOP": data["desktop"],
        "PL_MIN_RAM_MB": data["min_ram_mb"],
        "PL_RECOMMENDS": data.get("install_recommends", "false"),
        "PL_MAX_MB": data.get("max_uncompressed_mb", ""),
        "PL_PROFILE_VERSION": data.get("version", ""),
        "PL_PACKAGES": " ".join(data["packages"]),
        "PL_HOOKS": " ".join(data["hooks"]),
    }
    return "\n".join("%s=%s" % (k, shlex.quote(v)) for k, v in pairs.items())


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: plprofile.py FILE [--shell]\n")
        return 2
    try:
        data = load(argv[1])
    except (OSError, ProfileError) as exc:
        sys.stderr.write("profile error (%s): %s\n" % (argv[1], exc))
        return 1
    if "--shell" in argv[2:]:
        print(as_shell(data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
