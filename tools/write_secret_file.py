#!/usr/bin/env python3
"""Write one secret from the environment to a file mode 0600.

The secret value is never printed and is not passed on the command line.
`pem` writes an App Store Connect .p8. A value stored as one line with
literal backslash-n sequences is turned back into PEM lines. `b64` decodes
a base64 blob (newlines allowed) such as a .p12 or .mobileprovision.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import os
import stat
import sys
from pathlib import Path


def normalize_pem(raw: str) -> str:
    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    # A secret pasted as one line often stores the PEM breaks as the two characters \n.
    if "\\n" in text and "\n" not in text:
        text = text.replace("\\n", "\n")
    if "BEGIN PRIVATE KEY" not in text or "END PRIVATE KEY" not in text:
        raise SystemExit("secret is not a PEM private key (BEGIN PRIVATE KEY / END PRIVATE KEY)")
    if not text.endswith("\n"):
        text += "\n"
    return text


def decode_b64(raw: str) -> bytes:
    compact = "".join(raw.split())
    try:
        data = base64.b64decode(compact, validate=True)
    except binascii.Error as exc:
        raise SystemExit("secret is not valid base64") from exc
    if not data:
        raise SystemExit("secret decoded to an empty file")
    return data


def write_secret(kind: str, env_name: str, dest: Path) -> None:
    if env_name not in os.environ or os.environ[env_name] == "":
        raise SystemExit(f"missing secret {env_name}")
    raw = os.environ[env_name]
    dest.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(dest.parent, 0o700)
    if kind == "pem":
        payload = normalize_pem(raw).encode()
    elif kind == "b64":
        payload = decode_b64(raw)
    elif kind == "raw":
        payload = raw.encode()
    else:
        raise SystemExit(f"unknown kind {kind}")
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(dest, flags, 0o600)
    try:
        os.write(fd, payload)
    finally:
        os.close(fd)
    os.chmod(dest, stat.S_IRUSR | stat.S_IWUSR)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("pem", "b64", "raw"))
    parser.add_argument("env_name")
    parser.add_argument("dest", type=Path)
    args = parser.parse_args(argv)
    write_secret(args.kind, args.env_name, args.dest)
    print(f"wrote {args.dest.name} ({args.dest.stat().st_size} bytes, mode 600)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
