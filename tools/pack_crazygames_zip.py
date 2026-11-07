#!/usr/bin/env python3
"""Zip a CrazyGames web export and print raw and gzip sizes.

The zip root is the export directory (index.html beside index.wasm).
Paths inside the zip are relative. The CrazyGames limits checked here are
1500 files and 250MB raw. The initial-download budget (50MB, 20MB for the
mobile homepage) is reported, not failed, because the wasm template is the
bulk of it and a custom engine build is not part of this job.
"""

from __future__ import annotations

import gzip
import sys
import zipfile
from pathlib import Path


MAX_FILES = 1500
MAX_BYTES = 250 * 1024 * 1024
INITIAL_BUDGET = 50 * 1024 * 1024


def gzip_size(path: Path) -> int:
    return len(gzip.compress(path.read_bytes(), compresslevel=9))


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: pack_crazygames_zip.py BUILD_DIR ZIP_PATH")
    build = Path(sys.argv[1]).resolve()
    dest = Path(sys.argv[2]).resolve()
    if not (build / "index.html").is_file():
        raise SystemExit("missing %s" % (build / "index.html"))
    files = sorted(p for p in build.rglob("*") if p.is_file())
    if len(files) > MAX_FILES:
        raise SystemExit("%d files exceeds the CrazyGames limit of %d" % (len(files), MAX_FILES))
    html = (build / "index.html").read_text(errors="replace")
    for needle in ("user-select: none", "rawSafeInsets", "unlockGodotAudio"):
        if needle not in html:
            raise SystemExit("index.html is missing %s" % needle)
    if "requestFullscreen" in html or "fullscreenchange" in html:
        raise SystemExit("index.html has an in-page fullscreen control")
    # Game files must be relative. The shell may mention https only inside
    # comments; the engine config itself is a relative file name.
    if 'src="/' in html or "href='/" in html or 'href="/' in html:
        raise SystemExit("index.html has an absolute path")
    total = 0
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            rel = path.relative_to(build).as_posix()
            if rel.startswith("/") or rel.startswith("../"):
                raise SystemExit("refusing absolute zip path %s" % rel)
            archive.write(path, rel)
            total += path.stat().st_size
    if total > MAX_BYTES:
        raise SystemExit("raw export is %d bytes, over %d" % (total, MAX_BYTES))
    print("files %d" % len(files))
    print("raw_total %d" % total)
    print("zip %d" % dest.stat().st_size)
    interesting = []
    for path in files:
        name = path.name
        if name.startswith("index.") or name == "index.html":
            interesting.append(path)
    gzip_total = 0
    raw_interesting = 0
    for path in interesting:
        raw = path.stat().st_size
        packed = gzip_size(path)
        raw_interesting += raw
        gzip_total += packed
        print("file %s raw %d gzip %d" % (path.name, raw, packed))
    print("initial_raw %d" % raw_interesting)
    print("initial_gzip %d" % gzip_total)
    if raw_interesting > INITIAL_BUDGET:
        print("initial_raw_over_50mb 1")
    else:
        print("initial_raw_over_50mb 0")


if __name__ == "__main__":
    main()
