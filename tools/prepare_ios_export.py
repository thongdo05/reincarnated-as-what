#!/usr/bin/env python3
"""Set the iOS store version and, when asked, turn off test ads.

The TestFlight workflow runs this on the runner checkout. It does not commit
the result. Version (CFBundleShortVersionString) stays 1.0. The build number
(CFBundleVersion) is the GitHub run number so a second upload does not collide.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SHORT_VERSION_RE = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}$")
BUILD_NUMBER_RE = re.compile(r"^[1-9][0-9]*$")
USE_TEST_ADS_TRUE = "const USE_TEST_ADS := true"
USE_TEST_ADS_FALSE = "const USE_TEST_ADS := false"


def section_span(text: str, header: str) -> tuple[int, int]:
    token = header if header.startswith("[") else f"[{header}]"
    marker = token + "\n"
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f"export preset is missing {token}")
    rest = text[start + len(token) :]
    match = re.search(r"\n\[", rest)
    end = len(text) if match is None else start + len(token) + match.start()
    return start, end


def replace_quoted_key(text: str, header: str, key: str, value: str) -> str:
    if "\n" in value or '"' in value:
        raise SystemExit(f"refusing unsafe value for {key}")
    start, end = section_span(text, header)
    body = text[start:end]
    pattern = re.compile(rf'(?m)^{re.escape(key)}="[^"]*"\s*$')
    updated, count = pattern.subn(f'{key}="{value}"', body, count=1)
    if count != 1:
        raise SystemExit(f"expected exactly one {key} in {header}")
    return text[:start] + updated + text[end:]


def prepare_preset(text: str, short_version: str, build_number: str) -> str:
    if not SHORT_VERSION_RE.fullmatch(short_version):
        raise SystemExit("short version must look like 1.0")
    if not BUILD_NUMBER_RE.fullmatch(build_number):
        raise SystemExit("build number must be a positive integer")
    preset_start, preset_end = section_span(text, "[preset.1]")
    preset = text[preset_start:preset_end]
    if 'name="iOS"' not in preset:
        raise SystemExit("[preset.1] is not the iOS preset; refusing to edit it")
    text = replace_quoted_key(text, "[preset.1.options]", "application/short_version", short_version)
    text = replace_quoted_key(text, "[preset.1.options]", "application/version", build_number)
    return text


def prepare_project(text: str) -> str:
    """Godot rejects an iOS export unless ETC2/ASTC import is enabled.

    Pixel textures in this project stay lossless. The flag is only required
    for the export check. The TestFlight job writes it on the runner and does
    not commit it, so the web export's project file is unchanged.
    """
    enabled = "textures/vram_compression/import_etc2_astc=true"
    disabled = "textures/vram_compression/import_etc2_astc=false"
    if enabled in text:
        return text
    if disabled in text:
        return text.replace(disabled, enabled, 1)
    start, end = section_span(text, "[rendering]")
    body = text[start:end]
    header, _, rest = body.partition("\n")
    return text[:start] + header + "\n" + enabled + "\n" + rest + text[end:]


def prepare_store_config(text: str, use_real_ads: bool) -> tuple[str, bool]:
    has_true = USE_TEST_ADS_TRUE in text
    has_false = USE_TEST_ADS_FALSE in text
    if use_real_ads:
        if not has_true and not has_false:
            raise SystemExit("scripts/store_config.gd has no USE_TEST_ADS flag")
        if has_true:
            return text.replace(USE_TEST_ADS_TRUE, USE_TEST_ADS_FALSE, 1), False
        return text, False
    if not has_true:
        raise SystemExit(
            "USE_TEST_ADS is not true. The TestFlight workflow leaves the default "
            "alone unless the use_real_ads input is set."
        )
    return text, True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", type=Path, default=Path("export_presets.cfg"))
    parser.add_argument("--store-config", type=Path, default=Path("scripts/store_config.gd"))
    parser.add_argument("--project", type=Path, default=Path("project.godot"))
    parser.add_argument("--short-version", default="1.0")
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--use-real-ads", action="store_true")
    args = parser.parse_args(argv)

    preset_text = args.preset.read_text()
    updated_preset = prepare_preset(preset_text, args.short_version, args.build_number)
    args.preset.write_text(updated_preset)

    store_text = args.store_config.read_text()
    updated_store, test_ads = prepare_store_config(store_text, args.use_real_ads)
    args.store_config.write_text(updated_store)

    project_text = args.project.read_text()
    args.project.write_text(prepare_project(project_text))
    print("ETC2/ASTC import: enabled for this iOS export")

    print(f"iOS short version: {args.short_version}")
    print(f"iOS build number: {args.build_number}")
    print("USE_TEST_ADS: " + ("true" if test_ads else "false"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
