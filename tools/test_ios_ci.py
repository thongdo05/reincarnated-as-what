#!/usr/bin/env python3
"""Offline checks for the TestFlight workflow helpers. No Apple account and no secrets."""

from __future__ import annotations

import base64
import os
import plistlib
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

import check_ios_plugin_binaries
import ios_export_options
import ios_signing_bootstrap as bootstrap
import patch_admob_spm
import prepare_ios_export
import write_secret_file

ROOT = Path(__file__).resolve().parents[1]


def raw_to_der(raw: bytes) -> bytes:
    def encode(value: bytes) -> bytes:
        value = value.lstrip(b"\x00") or b"\x00"
        if value[0] & 0x80:
            value = b"\x00" + value
        return b"\x02" + bytes([len(value)]) + value

    body = encode(raw[:32]) + encode(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


class PrepareTests(unittest.TestCase):
    def test_version_and_ads_stay_in_their_lanes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            preset = root / "export_presets.cfg"
            store = root / "store_config.gd"
            project = root / "project.godot"
            shutil.copy(ROOT / "export_presets.cfg", preset)
            shutil.copy(ROOT / "scripts/store_config.gd", store)
            shutil.copy(ROOT / "project.godot", project)
            original_preset = preset.read_text()
            original_project = project.read_text()
            prepare_ios_export.main(
                [
                    "--preset",
                    str(preset),
                    "--store-config",
                    str(store),
                    "--project",
                    str(project),
                    "--build-number",
                    "42",
                ]
            )
            self.assertIn("textures/vram_compression/import_etc2_astc=true", project.read_text())
            self.assertIn('config/name="Reincarnated as WHAT?!"', project.read_text())
            self.assertEqual(
                original_project.split("[rendering]")[0],
                project.read_text().split("[rendering]")[0],
            )
            updated = preset.read_text()
            self.assertIn('application/short_version="1.0"', updated)
            self.assertIn('application/version="42"', updated)
            self.assertIn('name="Web"', updated)
            self.assertIn('export_path="build/web/index.html"', updated)
            self.assertIn('version/code=1', updated)
            self.assertIn('version/name=""', updated)
            self.assertNotIn('application/version="1"', updated.split("[preset.2]")[0])
            self.assertIn(prepare_ios_export.USE_TEST_ADS_TRUE, store.read_text())
            web_before = original_preset.split("[preset.1]")[0]
            web_after = updated.split("[preset.1]")[0]
            self.assertEqual(web_before, web_after)

            prepare_ios_export.main(
                [
                    "--preset",
                    str(preset),
                    "--store-config",
                    str(store),
                    "--project",
                    str(project),
                    "--build-number",
                    "43",
                    "--use-real-ads",
                ]
            )
            self.assertEqual(project.read_text().count("import_etc2_astc=true"), 1)
            self.assertIn(prepare_ios_export.USE_TEST_ADS_FALSE, store.read_text())
            self.assertNotIn(prepare_ios_export.USE_TEST_ADS_TRUE, store.read_text())
            self.assertIn('application/version="43"', preset.read_text())

    def test_rejects_a_non_ios_preset_slot(self) -> None:
        text = '[preset.1]\n\nname="Android"\n\n[preset.1.options]\n\napplication/short_version="1.0"\napplication/version="1"\n'
        with self.assertRaises(SystemExit):
            prepare_ios_export.prepare_preset(text, "1.0", "2")


class PatchTests(unittest.TestCase):
    def test_package_list_matches_the_admob_plugin(self) -> None:
        source = (ROOT / "addons/admob/ios/bin/ads/poing_godot_admob_ads.gd").read_text()
        for package in patch_admob_spm.PACKAGES:
            self.assertIn(package["version"], source)
            self.assertIn(package["url"], source)
            self.assertIn(package["product"], source)

    def test_patch_is_idempotent_on_the_godot_template_shape(self) -> None:
        template = """
/* Begin PBXBuildFile section */
		DEADBEEF /* app */ = {isa = PBXBuildFile; };
/* End PBXBuildFile section */

/* Begin PBXFrameworksBuildPhase section */
		FRAME /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			files = (
				DEADBEEF /* app */,
			);
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		GROUP = { isa = PBXGroup; };
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		TARGET = {
			isa = PBXNativeTarget;
			buildRules = (
			);
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		PROJECT = {
			isa = PBXProject;
			productRefGroup = GROUP /* Products */;
		};
/* End PBXProject section */
"""
        once = patch_admob_spm.patch_pbxproj(template)
        twice = patch_admob_spm.patch_pbxproj(once)
        self.assertEqual(once, twice)
        self.assertGreaterEqual(once.count(patch_admob_spm.MARKER), 2)
        self.assertEqual(once.count("PoingGodotAdMobDeps in Frameworks"), 2)
        self.assertIn("PoingGodotAdMobDeps", once)
        self.assertIn('relativePath = "admob_spm"', once)
        swift = patch_admob_spm.package_swift()
        self.assertIn('exact: "13.9.0"', swift)
        self.assertIn('exact: "3.1.0"', swift)
        self.assertIn("GoogleMobileAds", swift)
        self.assertIn("GoogleUserMessagingPlatform", swift)


class SecretFileTests(unittest.TestCase):
    def test_pem_literal_newlines_and_base64(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "key.p8"
            pem = "-----BEGIN PRIVATE KEY-----\nABC\n-----END PRIVATE KEY-----\n"
            env = os.environ.copy()
            env["TEST_P8"] = pem.replace("\n", "\\n")
            env["TEST_B64"] = base64.b64encode(b"p12-bytes").decode()
            subprocess.run(
                ["python3", str(ROOT / "tools/write_secret_file.py"), "pem", "TEST_P8", str(dest)],
                check=True,
                env=env,
                cwd=tmp,
            )
            written = dest.read_text()
            self.assertIn("BEGIN PRIVATE KEY", written)
            self.assertIn("-----BEGIN PRIVATE KEY-----\nABC\n-----END PRIVATE KEY-----", written)
            self.assertEqual(dest.stat().st_mode & 0o777, 0o600)
            blob = Path(tmp) / "dist.p12"
            subprocess.run(
                ["python3", str(ROOT / "tools/write_secret_file.py"), "b64", "TEST_B64", str(blob)],
                check=True,
                env=env,
                cwd=tmp,
            )
            self.assertEqual(blob.read_bytes(), b"p12-bytes")


class ExportOptionsTests(unittest.TestCase):
    def test_manual_app_store_plist(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ExportOptions.plist"
            ios_export_options.write_export_options(
                path, "9589T6378Y", "com.thongdo.reincarnatedaswhat", "reincarnatedaswhat App Store"
            )
            with path.open("rb") as handle:
                data = plistlib.load(handle)
        self.assertEqual(data["method"], "app-store-connect")
        self.assertEqual(data["signingStyle"], "manual")
        self.assertNotIn("allowProvisioningUpdates", str(data))
        self.assertEqual(
            data["provisioningProfiles"]["com.thongdo.reincarnatedaswhat"],
            "reincarnatedaswhat App Store",
        )


class BootstrapTests(unittest.TestCase):
    def test_decide_creates_once(self) -> None:
        self.assertEqual(bootstrap.decide([], bootstrap.CONFIRM_CREATE, "", False), "create")
        existing = [{"id": "CERT1", "expirationDate": "2027-01-01"}]
        with self.assertRaises(SystemExit):
            bootstrap.decide(existing, bootstrap.CONFIRM_CREATE, "", False)
        self.assertEqual(
            bootstrap.decide(existing, bootstrap.CONFIRM_REVOKE, "CERT1", False),
            "revoke_then_create",
        )
        with self.assertRaises(SystemExit):
            bootstrap.decide(existing, bootstrap.CONFIRM_REVOKE, "OTHER", False)
        self.assertEqual(
            bootstrap.decide(existing, bootstrap.CONFIRM_REFRESH, "", True),
            "refresh",
        )
        with self.assertRaises(SystemExit):
            bootstrap.decide([], bootstrap.CONFIRM_REFRESH, "", True)

    def test_jwt_es256_verifies(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp) / "key.p8"
            pub = Path(tmp) / "pub.pem"
            subprocess.run(
                ["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)],
                check=True,
                capture_output=True,
            )
            subprocess.run(
                ["openssl", "pkey", "-in", str(key), "-pubout", "-out", str(pub)],
                check=True,
                capture_output=True,
            )
            token = bootstrap.make_jwt(key, "KEYID12345", "issuer-id", "openssl", now=1_700_000_000)
            header, payload, signature = token.split(".")
            signing_input = f"{header}.{payload}".encode()
            der = raw_to_der(base64.urlsafe_b64decode(signature + "=" * (-len(signature) % 4)))
            data_path = Path(tmp) / "data"
            sig_path = Path(tmp) / "sig.der"
            data_path.write_bytes(signing_input)
            sig_path.write_bytes(der)
            subprocess.run(
                [
                    "openssl",
                    "dgst",
                    "-sha256",
                    "-verify",
                    str(pub),
                    "-signature",
                    str(sig_path),
                    str(data_path),
                ],
                check=True,
                capture_output=True,
            )

    def test_create_bundle_roundtrip_without_apple(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            output = work / "bundle.tar.gz.enc"
            password = "0123456789abcdef"
            (work / "export-password.txt").write_text(password)

            class Fake:
                def __init__(self) -> None:
                    self.paths: list[str] = []

                def __call__(self, method: str, path: str, body: dict | None, token: str):
                    self.paths.append(method + " " + path)
                    if "IOS_DISTRIBUTION" in path:
                        return 200, {"data": []}
                    if path.startswith("/v1/certificates?"):
                        return 200, {"data": []}
                    if path.startswith("/v1/bundleIds?"):
                        return 200, {
                            "data": [
                                {
                                    "id": "BUNDLE123",
                                    "attributes": {"identifier": bootstrap.BUNDLE_ID},
                                }
                            ]
                        }
                    if "bundleIdCapabilities" in path and method == "GET":
                        return 200, {"data": [{"attributes": {"capabilityType": "IN_APP_PURCHASE"}}]}
                    if method == "POST" and path == "/v1/certificates":
                        csr = work / "request.csr"
                        cert = work / "issued.pem"
                        csr.write_text(body["data"]["attributes"]["csrContent"])
                        # Sign the CSR with a throwaway CA. The public key stays the CSR's key.
                        ca_key = work / "ca.key"
                        ca_cert = work / "ca.pem"
                        subprocess.run(["openssl", "genrsa", "-out", str(ca_key), "2048"], check=True, capture_output=True)
                        subprocess.run(
                            [
                                "openssl",
                                "req",
                                "-new",
                                "-x509",
                                "-key",
                                str(ca_key),
                                "-out",
                                str(ca_cert),
                                "-days",
                                "1",
                                "-subj",
                                "/CN=Test CA",
                            ],
                            check=True,
                            capture_output=True,
                        )
                        subprocess.run(
                            [
                                "openssl",
                                "x509",
                                "-req",
                                "-in",
                                str(csr),
                                "-CA",
                                str(ca_cert),
                                "-CAkey",
                                str(ca_key),
                                "-CAcreateserial",
                                "-out",
                                str(cert),
                                "-days",
                                "1",
                            ],
                            check=True,
                            capture_output=True,
                        )
                        der = subprocess.check_output(["openssl", "x509", "-in", str(cert), "-outform", "DER"])
                        return 201, {
                            "data": {
                                "id": "CERTNEW",
                                "attributes": {
                                    "certificateContent": base64.b64encode(der).decode(),
                                    "displayName": "Apple Distribution: Test",
                                    "expirationDate": "2027-01-01",
                                    "certificateType": "DISTRIBUTION",
                                    "serialNumber": "01",
                                },
                            }
                        }
                    if path.startswith("/v1/profiles?"):
                        return 200, {"data": []}
                    if method == "POST" and path == "/v1/profiles":
                        return 201, {
                            "data": {
                                "id": "PROF1",
                                "attributes": {
                                    "name": bootstrap.PROFILE_NAME,
                                    "profileContent": base64.b64encode(b"profile-bytes").decode(),
                                },
                            }
                        }
                    raise AssertionError(method + " " + path)

            args = bootstrap.build_parser().parse_args(
                [
                    "--issuer-id",
                    "issuer",
                    "--key-id",
                    "KEYID12345",
                    "--key-path",
                    str(self._signing_key(work)),
                    "--export-password-file",
                    str(work / "export-password.txt"),
                    "--confirm",
                    bootstrap.CONFIRM_CREATE,
                    "--output",
                    str(output),
                    "--openssl",
                    "openssl",
                ]
            )
            fake = Fake()
            bootstrap.run(args, request=fake)
            self.assertTrue(any(item.startswith("POST /v1/certificates") for item in fake.paths))
            unpacked = work / "unpacked"
            unpacked.mkdir()
            plain = work / "plain.tar.gz"
            subprocess.run(
                [
                    "openssl",
                    "enc",
                    "-d",
                    "-aes-256-cbc",
                    "-pbkdf2",
                    "-iter",
                    "200000",
                    "-salt",
                    "-in",
                    str(output),
                    "-out",
                    str(plain),
                    "-pass",
                    f"pass:{password}",
                ],
                check=True,
                capture_output=True,
            )
            with tarfile.open(plain) as archive:
                archive.extractall(unpacked, filter="data")
            self.assertEqual((unpacked / "appstore.mobileprovision").read_bytes(), b"profile-bytes")
            p12_password = (unpacked / "p12-password.txt").read_text()
            self.assertNotIn("\n", p12_password)
            info = subprocess.run(
                [
                    "openssl",
                    "pkcs12",
                    "-in",
                    str(unpacked / "distribution.p12"),
                    "-nokeys",
                    "-passin",
                    f"pass:{p12_password}",
                ],
                check=True,
                capture_output=True,
            )
            self.assertIn(b"BEGIN CERTIFICATE", info.stdout)
            self.assertIn("IOS_DISTRIBUTION_P12_BASE64", (unpacked / "README.txt").read_text())

    def _signing_key(self, work: Path) -> Path:
        key = work / "api.p8"
        subprocess.run(
            ["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)],
            check=True,
            capture_output=True,
        )
        return key


class WorkflowTests(unittest.TestCase):
    def test_workflows_are_manual_and_do_not_mint_a_cert_per_build(self) -> None:
        testflight = (ROOT / ".github/workflows/ios-testflight.yml").read_text()
        bootstrap_yaml = (ROOT / ".github/workflows/ios-signing-bootstrap.yml").read_text()
        pages = (ROOT / ".github/workflows/pages.yml").read_text()
        for text in (testflight, bootstrap_yaml):
            self.assertIn("workflow_dispatch:", text)
            self.assertNotIn("\n  push:", text)
            self.assertNotIn("\n  pull_request:", text)
        self.assertIn('runs-on: macos-26', testflight)
        self.assertIn("ASC_APP_APPLE_ID: \"6831784046\"", testflight)
        self.assertIn("use_real_ads:", testflight)
        self.assertNotIn("use_real_ads:", pages)
        script = (ROOT / "tools/ios_archive_and_upload.sh").read_text()
        for line in script.splitlines():
            if line.strip().startswith("#"):
                continue
            self.assertNotIn("-allowProvisioningUpdates", line)
            self.assertNotIn('echo "$APP_STORE_CONNECT_API_KEY_P8"', line)
            self.assertNotIn('echo "$IOS_DISTRIBUTION_P12', line)
            self.assertNotIn('echo "$IOS_PROVISIONING_PROFILE', line)
        self.assertIn("github.run_number", testflight)
        self.assertIn('IOS_SHORT_VERSION: "1.0"', testflight)

    def test_vendored_plugin_binaries(self) -> None:
        previous = os.getcwd()
        os.chdir(ROOT)
        try:
            check_ios_plugin_binaries.check(download_missing_admob=False)
        finally:
            os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
