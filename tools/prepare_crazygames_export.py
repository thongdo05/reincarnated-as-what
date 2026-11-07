#!/usr/bin/env python3
"""Prepare a working tree for the CrazyGames web export.

The GitHub Pages preset and the iOS/Android presets do not run this.
It does two things, both local to the checkout:

1. Registers the official addon autoloads in project.godot. The committed
   file leaves them out so the Pages, iOS, and Android exports do not boot
   the SDK.
2. Re-encodes the long music loops to 80 kbps Vorbis. Short stings and WAV
   effects are left alone. Godot reimports the changed files on the next
   headless import.

`--self-test` checks the autoload edit and the bitrate skip on temp files
and does not touch the project.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
BRIDGE = 'CrazyGamesBridge="*res://addons/crazygames/Utils/CrazyGamesBridge.gd"'
GAME = 'CrazyGames="*res://addons/crazygames/CrazyGames.gd"'
MUSIC_BITRATE = "80k"
# Skip a file that is already near the target. A second run must not
# squash an 80 kbps loop again.
ALREADY_SMALL = 110_000

MUSIC_GLOBS = (
    "audio/music/*.ogg",
    "audio/music_gameplay_loop.ogg",
)


def ensure_autoloads(text: str) -> str:
    if BRIDGE in text and GAME in text:
        return text
    needle = 'Monetization="*res://scripts/monetization.gd"\n'
    if needle not in text:
        raise SystemExit("project.godot is missing the Monetization autoload")
    insert = needle + BRIDGE + "\n" + GAME + "\n"
    return text.replace(needle, insert, 1)


def music_paths(root: Path) -> list[Path]:
    found: list[Path] = []
    for pattern in MUSIC_GLOBS:
        found.extend(sorted(root.glob(pattern)))
    return found


def bitrate_of(path: Path) -> int:
    probe = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=bit_rate",
            "-of",
            "default=nw=1:nk=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    raw = probe.stdout.strip().splitlines()
    if not raw or raw[0] in ("", "N/A"):
        return 0
    return int(float(raw[0]))


def recompress(path: Path) -> bool:
    current = bitrate_of(path)
    if 0 < current <= ALREADY_SMALL:
        print("keep %s (%d bps)" % (path.name, current))
        return False
    print("recompress %s (%d bps -> %s)" % (path.name, current, MUSIC_BITRATE))
    dest = path.with_suffix(".crazygames.ogg")
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(path),
            "-c:a",
            "libvorbis",
            "-b:a",
            MUSIC_BITRATE,
            "-ar",
            "48000",
            "-ac",
            "2",
            str(dest),
        ],
        check=True,
        capture_output=True,
    )
    dest.replace(path)
    return True


def self_test() -> None:
    sample = '[autoload]\n\nMonetization="*res://scripts/monetization.gd"\n\n[display]\n'
    once = ensure_autoloads(sample)
    twice = ensure_autoloads(once)
    if once != twice:
        raise SystemExit("autoload edit is not idempotent")
    if once.count(BRIDGE) != 1 or once.count(GAME) != 1:
        raise SystemExit("autoload edit did not insert both singletons")
    if not (ROOT / "addons/crazygames/CrazyGames.gd").is_file():
        raise SystemExit("missing addons/crazygames/CrazyGames.gd")
    if not (ROOT / "addons/crazygames/Utils/CrazyGamesBridge.gd").is_file():
        raise SystemExit("missing CrazyGamesBridge.gd")
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "tone.ogg"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=440:duration=0.3",
                "-c:a",
                "libvorbis",
                "-b:a",
                "32k",
                str(src),
            ],
            check=True,
            capture_output=True,
        )
        if bitrate_of(src) > ALREADY_SMALL:
            raise SystemExit("test tone was not small")
        before = src.read_bytes()
        if recompress(src):
            raise SystemExit("a short low-bitrate file should be kept")
        if src.read_bytes() != before:
            raise SystemExit("kept file was rewritten")
    print("prepare_crazygames_export.py self-test ok")


def main() -> None:
    if "--self-test" in sys.argv:
        self_test()
        return
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise SystemExit("ffmpeg and ffprobe are required")
    PROJECT.write_text(ensure_autoloads(PROJECT.read_text()))
    changed = 0
    for path in music_paths(ROOT):
        if recompress(path):
            changed += 1
    print("music files recompressed: %d" % changed)


if __name__ == "__main__":
    main()
