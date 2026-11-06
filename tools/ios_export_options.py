#!/usr/bin/env python3
"""Write the manual-signing ExportOptions.plist used for the App Store IPA.

xcodebuild is not given -allowProvisioningUpdates. The profile name is the
Name inside the .mobileprovision installed from secrets, so this file never
asks Xcode to create a certificate.
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path


def export_options(team_id: str, bundle_id: str, profile_name: str) -> dict:
    if not team_id or not bundle_id or not profile_name:
        raise SystemExit("team id, bundle id, and profile name are required")
    return {
        "method": "app-store-connect",
        "signingStyle": "manual",
        "teamID": team_id,
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {bundle_id: profile_name},
        "uploadSymbols": False,
        "destination": "export",
    }


def write_export_options(path: Path, team_id: str, bundle_id: str, profile_name: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(export_options(team_id, bundle_id, profile_name), handle, fmt=plistlib.FMT_XML)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--profile-name", required=True)
    args = parser.parse_args(argv)
    write_export_options(args.output, args.team_id, args.bundle_id, args.profile_name)
    print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
