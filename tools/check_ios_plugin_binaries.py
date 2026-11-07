#!/usr/bin/env python3
"""Check the iOS plugin static libraries the export links.

AdMob, StoreKit IAP, and App Tracking Transparency binaries are vendored.
If the AdMob release library is missing, this can download the ads module
from the Poing Studios v5.1.0 release built for Godot 4.7.2. Mediation
networks in that zip are not extracted. IAP and ATT are not downloaded.
"""

from __future__ import annotations

import argparse
import io
import sys
import urllib.request
import zipfile
from pathlib import Path


ADMOB_RELEASE = Path(
    "addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.release.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release.a"
)
IAP_RELEASE = Path(
    "ios/plugins/ios-in-app-purchase/ios-in-app-purchase.release.xcframework/ios-arm64/ios-in-app-purchase.a"
)
ATT_RELEASE = Path(
    "ios/plugins/godot-ios-att/godot-ios-att.release.xcframework/ios-arm64/libgodot-ios-att.a"
)
SHARE_SOURCE = Path("ios/plugins/share_sheet/share_sheet.mm")
SHARE_CONFIG = Path("ios/plugins/share_sheet/share_sheet.gdip")

ADMOB_VERSION = "v5.1.0"
GODOT_TEMPLATE_VERSION = "v4.7.2"
ADMOB_IOS_URL = (
    "https://github.com/poingstudios/godot-admob-plugin/releases/download/"
    f"{ADMOB_VERSION}/ios-template-{GODOT_TEMPLATE_VERSION}.zip"
)
ADMOB_EXTRACT_ROOT = Path("addons/admob/ios/bin")
AR_MAGIC = b"!<arch>\n"


def is_static_archive(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 8:
        return False
    with path.open("rb") as handle:
        return handle.read(8) == AR_MAGIC


def install_admob_ads(url: str = ADMOB_IOS_URL, dest: Path = ADMOB_EXTRACT_ROOT) -> None:
    print(f"AdMob iOS release library is missing. Downloading ads module from {url}")
    with urllib.request.urlopen(url, timeout=120) as response:
        payload = response.read()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        members = [name for name in archive.namelist() if name.startswith("ads/") and not name.endswith("/")]
        if not members:
            raise SystemExit("AdMob iOS zip has no ads/ files")
        for name in members:
            target = dest / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
    print(f"Installed {len(members)} AdMob ads files under {dest / 'ads'}")


def check(download_missing_admob: bool) -> None:
    if not is_static_archive(ADMOB_RELEASE):
        if not download_missing_admob:
            raise SystemExit(f"missing AdMob iOS binary: {ADMOB_RELEASE}")
        install_admob_ads()
    if not is_static_archive(ADMOB_RELEASE):
        raise SystemExit(f"AdMob iOS binary is not a static library: {ADMOB_RELEASE}")

    missing = [path for path in (IAP_RELEASE, ATT_RELEASE) if not is_static_archive(path)]
    if missing:
        joined = ", ".join(str(path) for path in missing)
        raise SystemExit(
            "missing vendored iOS plugin binary: "
            + joined
            + ". These are committed under ios/plugins and are not downloaded in CI."
        )
    print("iOS plugin binaries: AdMob ads, StoreKit IAP, and ATT release libraries are present")
    check_share_sheet_source()


def check_share_sheet_source() -> None:
    """The share sheet library is compiled on the macOS runner, not vendored."""
    if not SHARE_SOURCE.is_file() or not SHARE_CONFIG.is_file():
        raise SystemExit("the iOS share sheet plugin source is missing")
    source = SHARE_SOURCE.read_text(encoding="utf-8")
    config = SHARE_CONFIG.read_text(encoding="utf-8")
    for needle in ("void share_sheet_init()", "void share_sheet_deinit()", "UIActivityViewController"):
        if needle not in source:
            raise SystemExit(f"share sheet source is missing {needle}")
    for needle in ('name="ShareSheet"', 'initialization="share_sheet_init"', "UIKit.framework"):
        if needle not in config:
            raise SystemExit(f"share sheet gdip is missing {needle}")
    print("iOS share sheet plugin source is present (xcframework is built on the TestFlight runner)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--download-missing-admob",
        action="store_true",
        help="Download the AdMob ads xcframework if the vendored copy is missing",
    )
    args = parser.parse_args(argv)
    check(args.download_missing_admob)
    return 0


if __name__ == "__main__":
    sys.exit(main())
