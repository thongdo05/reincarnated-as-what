#!/usr/bin/env python3
"""Ensure the exported Xcode project links the AdMob Swift packages.

Godot 4.7 calls the AdMob exporter's end_generate hook on macOS, and that
hook patches project.pbxproj. This script repeats the same patch so the
archive still gets Google Mobile Ads if that hook did not run. Running it
twice does not duplicate the package.

The package list matches get_spm_packages() in
addons/admob/ios/bin/ads/poing_godot_admob_ads.gd. The pbxproj edits match
addons/admob/internal/services/pbxproj_service.gd.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


PACKAGES = (
    {
        "url": "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
        "version": "13.9.0",
        "product": "GoogleMobileAds",
    },
    {
        "url": "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
        "version": "3.1.0",
        "product": "GoogleUserMessagingPlatform",
    },
)

MARKER = "AD0000000000000000000001"
LOCAL_REF_ID = "AD0000000000000000000001"
PRODUCT_DEP_ID = "AD0000000000000000000002"
BUILD_FILE_ID = "AD0000000000000000000003"


def package_swift(packages: tuple[dict[str, str], ...] = PACKAGES) -> str:
    package_deps = []
    target_deps = []
    seen_urls: list[str] = []
    seen_products: list[str] = []
    for dep in packages:
        url = dep["url"]
        product = dep["product"]
        package_name = url.rsplit("/", 1)[-1].removesuffix(".git")
        if url not in seen_urls:
            seen_urls.append(url)
            package_deps.append(f'        .package(url: "{url}", exact: "{dep["version"]}"),')
        if product not in seen_products:
            seen_products.append(product)
            target_deps.append(
                f'                .product(name: "{product}", package: "{package_name}"),'
            )
    package_deps_str = "\n".join(package_deps)
    target_deps_str = "\n".join(target_deps)
    return f"""// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PoingGodotAdMobDeps",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "PoingGodotAdMobDeps",
            targets: ["PoingGodotAdMobDeps"]),
    ],
    dependencies: [
{package_deps_str}
    ],
    targets: [
        .target(
            name: "PoingGodotAdMobDeps",
            dependencies: [
{target_deps_str}
            ],
            path: "PoingGodotAdMobDeps",
            linkerSettings: [
                .linkedFramework("JavaScriptCore")
            ]
        )
    ]
)
"""


DUMMY_SWIFT = """// Dummy
import Foundation

public struct PoingGodotAdMobDeps {
    public init() {}
}
"""


def write_package(export_dir: Path) -> None:
    package_dir = export_dir / "admob_spm"
    source_dir = package_dir / "PoingGodotAdMobDeps"
    source_dir.mkdir(parents=True, exist_ok=True)
    (package_dir / "Package.swift").write_text(package_swift())
    (source_dir / "Dummy.swift").write_text(DUMMY_SWIFT)


def patch_pbxproj(content: str) -> str:
    """Same edits as PbxprojService.patch. A second call is a no-op."""
    if not content:
        return content
    if MARKER in content:
        return content

    if "/* Begin XCLocalSwiftPackageReference section */" not in content:
        content = content.replace(
            "/* End PBXGroup section */",
            "/* End PBXGroup section */\n\n/* Begin XCLocalSwiftPackageReference section */\n/* End XCLocalSwiftPackageReference section */",
            1,
        )
    if "/* Begin XCSwiftPackageProductDependency section */" not in content:
        content = content.replace(
            "/* End XCLocalSwiftPackageReference section */",
            "/* End XCLocalSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n/* End XCSwiftPackageProductDependency section */",
            1,
        )

    local_ref_def = (
        "\t\t"
        + LOCAL_REF_ID
        + ' /* XCLocalSwiftPackageReference "admob_spm" */ = {\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = "admob_spm";\n\t\t};\n'
    )
    content = content.replace(
        "/* End XCLocalSwiftPackageReference section */",
        local_ref_def + "/* End XCLocalSwiftPackageReference section */",
    )
    product_dep_def = (
        "\t\t"
        + PRODUCT_DEP_ID
        + " /* PoingGodotAdMobDeps */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = "
        + LOCAL_REF_ID
        + ' /* XCLocalSwiftPackageReference "admob_spm" */;\n\t\t\tproductName = "PoingGodotAdMobDeps";\n\t\t};\n'
    )
    content = content.replace(
        "/* End XCSwiftPackageProductDependency section */",
        product_dep_def + "/* End XCSwiftPackageProductDependency section */",
    )
    build_file_def = (
        "\t\t"
        + BUILD_FILE_ID
        + " /* PoingGodotAdMobDeps in Frameworks */ = {isa = PBXBuildFile; productRef = "
        + PRODUCT_DEP_ID
        + " /* PoingGodotAdMobDeps */; };\n"
    )
    content = content.replace(
        "/* Begin PBXBuildFile section */",
        "/* Begin PBXBuildFile section */\n" + build_file_def,
    )

    if "$spm_packages" in content:
        content = content.replace(
            "$spm_packages",
            LOCAL_REF_ID + ' /* XCLocalSwiftPackageReference "admob_spm" */',
        )
    elif "packageReferences = (" in content:
        content = content.replace(
            "packageReferences = (",
            "packageReferences = (\n\t\t\t\t"
            + LOCAL_REF_ID
            + ' /* XCLocalSwiftPackageReference "admob_spm" */,',
        )
    else:
        content = content.replace(
            "productRefGroup =",
            "packageReferences = (\n\t\t\t\t"
            + LOCAL_REF_ID
            + ' /* XCLocalSwiftPackageReference "admob_spm" */,\n\t\t\t);\n\t\t\tproductRefGroup =',
        )

    if "packageProductDependencies = (" in content:
        content = content.replace(
            "packageProductDependencies = (",
            "packageProductDependencies = (\n\t\t\t\t"
            + PRODUCT_DEP_ID
            + " /* PoingGodotAdMobDeps */,",
        )
    else:
        content = content.replace(
            "buildRules = (",
            "packageProductDependencies = (\n\t\t\t\t"
            + PRODUCT_DEP_ID
            + " /* PoingGodotAdMobDeps */,\n\t\t\t);\n\t\t\tbuildRules = (",
        )

    framework_at = content.find("isa = PBXFrameworksBuildPhase;")
    if framework_at != -1:
        files_at = content.find("files = (", framework_at)
        if files_at != -1:
            content = (
                content[: files_at + 9]
                + "\n\t\t\t\t"
                + BUILD_FILE_ID
                + " /* PoingGodotAdMobDeps in Frameworks */,"
                + content[files_at + 9 :]
            )

    content = content.replace("$spm_package_refs", "")
    content = content.replace("$spm_package_products", "")
    return content


def pbxproj_path(export_ipa: Path) -> Path:
    export_dir = export_ipa.parent
    direct = export_dir / f"{export_ipa.stem}.xcodeproj" / "project.pbxproj"
    if direct.is_file():
        return direct
    found = sorted(export_dir.glob("*.xcodeproj/project.pbxproj"))
    if len(found) == 1:
        return found[0]
    raise SystemExit(f"could not find the exported Xcode project under {export_dir}")


def ensure(export_ipa: Path) -> str:
    project = pbxproj_path(export_ipa)
    write_package(export_ipa.parent)
    original = project.read_text()
    updated = patch_pbxproj(original)
    if updated != original:
        project.write_text(updated)
        return "patched"
    if MARKER not in updated:
        raise SystemExit(f"AdMob Swift package patch did not apply to {project}")
    return "already-patched"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "export_ipa",
        type=Path,
        help="Godot export path, for example build/ios/reincarnated.ipa",
    )
    args = parser.parse_args(argv)
    status = ensure(args.export_ipa)
    print(f"AdMob Swift package: {status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
