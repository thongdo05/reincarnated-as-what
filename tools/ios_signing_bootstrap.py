#!/usr/bin/env python3
"""Create one Apple Distribution certificate and an App Store profile.

Local only. Do not run this from GitHub Actions and do not upload the .p12,
the profile, or --work-dir. The repository is public, so an Actions artifact
would be public. Apple allows one Apple Distribution certificate per team and
will not return the private key later.

Pass a temporary Admin API key on the command line. The TestFlight workflow
uses the App Manager key and the saved .p12. It does not call this script.

--work-dir is kept if a later step fails after Apple has issued the
certificate, so the private key is not deleted with a temp directory.
Nothing secret is printed.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import plistlib
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


API = "https://api.appstoreconnect.apple.com"
TEAM_ID = "9589T6378Y"
BUNDLE_ID = "com.thongdo.reincarnatedaswhat"
PROFILE_NAME = "reincarnatedaswhat App Store"

CONFIRM_CREATE = "CREATE-ONE-DISTRIBUTION-CERT"
CONFIRM_REVOKE = "REVOKE-AND-CREATE-ONE-DISTRIBUTION-CERT"
CONFIRM_REFRESH = "REFRESH-APP-STORE-PROFILE"

DECRYPT_COMMAND = """openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -salt \\
  -in ios-signing-bundle.tar.gz.enc \\
  -out ios-signing-bundle.tar.gz \\
  -pass env:IOS_SIGNING_EXPORT_PASSWORD
tar -xzf ios-signing-bundle.tar.gz"""


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes, size: int = 32) -> bytes:
    if not der or der[0] != 0x30:
        raise ValueError("ECDSA signature is not a DER sequence")
    index = 2
    if der[1] & 0x80:
        index = 2 + (der[1] & 0x7F)

    def read_int(at: int) -> tuple[bytes, int]:
        if der[at] != 0x02:
            raise ValueError("ECDSA signature is missing an integer")
        length = der[at + 1]
        start = at + 2
        return der[start : start + length], start + length

    raw_r, index = read_int(index)
    raw_s, _index = read_int(index)

    def pad(value: bytes) -> bytes:
        value = value.lstrip(b"\x00") or b"\x00"
        if len(value) > size:
            raise ValueError("ECDSA integer does not fit P-256")
        return value.rjust(size, b"\x00")

    return pad(raw_r) + pad(raw_s)


def openssl_dgst_sign(key_path: Path, data: bytes, openssl: str) -> bytes:
    with tempfile.TemporaryDirectory() as tmp:
        data_path = Path(tmp) / "data"
        sig_path = Path(tmp) / "sig"
        data_path.write_bytes(data)
        result = subprocess.run(
            [openssl, "dgst", "-sha256", "-sign", str(key_path), "-out", str(sig_path), str(data_path)],
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            raise SystemExit("openssl could not sign the App Store Connect JWT")
        return sig_path.read_bytes()


def make_jwt(key_path: Path, key_id: str, issuer_id: str, openssl: str, now: int | None = None) -> str:
    if now is None:
        now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64url(
        json.dumps(
            {"iss": issuer_id, "iat": now - 30, "exp": now + 600, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}"
    signature = der_to_raw(openssl_dgst_sign(key_path, signing_input.encode(), openssl))
    return f"{signing_input}.{b64url(signature)}"


def default_request(method: str, path: str, body: dict | None, token: str) -> tuple[int, dict]:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            status = response.status
            raw = response.read()
    except urllib.error.HTTPError as exc:
        status = exc.code
        raw = exc.read()
    if not raw:
        return status, {}
    try:
        payload = json.loads(raw.decode())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"App Store Connect returned HTTP {status} with a non-JSON body") from exc
    return status, payload


def error_text(status: int, payload: dict) -> str:
    parts = []
    for item in payload.get("errors") or []:
        title = str(item.get("title") or "")
        detail = str(item.get("detail") or "")
        parts.append(f"{title}: {detail}".strip(": "))
    detail = "; ".join(parts) if parts else "request failed"
    return f"App Store Connect HTTP {status}: {detail}"


def summarize_cert(item: dict) -> dict[str, str]:
    attributes = item.get("attributes") or {}
    return {
        "id": str(item.get("id") or ""),
        "expirationDate": str(attributes.get("expirationDate") or ""),
        "displayName": str(attributes.get("displayName") or attributes.get("name") or ""),
        "certificateType": str(attributes.get("certificateType") or ""),
        "serialNumber": str(attributes.get("serialNumber") or ""),
    }


def format_certs(certs: list[dict[str, str]], title: str = "Apple Distribution certificates on the team") -> str:
    if not certs:
        return f"{title}: none"
    lines = [f"{title}:"]
    for cert in certs:
        lines.append(
            f"  id={cert['id']} expires={cert['expirationDate']} name={cert['displayName']}"
        )
    return "\n".join(lines)


def decide(certs: list[dict[str, str]], confirm: str, revoke_id: str, refresh: bool) -> str:
    confirm = confirm.strip()
    revoke_id = revoke_id.strip()
    if refresh:
        if confirm != CONFIRM_REFRESH:
            raise SystemExit(
                "refresh_profile_only requires confirm to be exactly REFRESH-APP-STORE-PROFILE"
            )
        if len(certs) != 1:
            raise SystemExit(
                "profile refresh needs exactly one Apple Distribution certificate, "
                f"found {len(certs)}. No certificate was created."
            )
        return "refresh"
    if confirm == CONFIRM_CREATE:
        if revoke_id:
            raise SystemExit("revoke_certificate_id is only used with the revoke confirmation")
        if certs:
            listed = "; ".join(f"{cert['id']} (expires {cert['expirationDate']})" for cert in certs)
            raise SystemExit(
                "Refusing to create another Apple Distribution certificate. Apple allows one "
                "per team, and the private key cannot be downloaded again. "
                f"Existing: {listed}. If you already saved the .p12, skip this workflow and "
                "store that .p12 plus an App Store profile as the TestFlight secrets. If this "
                "certificate was created without a saved private key, re-run with confirm "
                "REVOKE-AND-CREATE-ONE-DISTRIBUTION-CERT and revoke_certificate_id set to that id."
            )
        return "create"
    if confirm == CONFIRM_REVOKE:
        if not revoke_id:
            raise SystemExit("REVOKE-AND-CREATE-ONE-DISTRIBUTION-CERT requires revoke_certificate_id")
        if revoke_id not in {cert["id"] for cert in certs}:
            raise SystemExit(
                "revoke_certificate_id does not match an Apple Distribution certificate. "
                "Nothing was revoked."
            )
        return "revoke_then_create"
    raise SystemExit(
        "confirm must be exactly CREATE-ONE-DISTRIBUTION-CERT, "
        "REVOKE-AND-CREATE-ONE-DISTRIBUTION-CERT, or REFRESH-APP-STORE-PROFILE"
    )


def list_certificates(request, token: str, certificate_type: str) -> list[dict[str, str]]:
    query = urllib.parse.urlencode({"filter[certificateType]": certificate_type, "limit": "20"})
    status, payload = request("GET", f"/v1/certificates?{query}", None, token)
    if status != 200:
        raise SystemExit(error_text(status, payload))
    return [summarize_cert(item) for item in payload.get("data") or []]


def find_bundle(request, token: str) -> str:
    query = urllib.parse.urlencode({"filter[identifier]": BUNDLE_ID, "limit": "5"})
    status, payload = request("GET", f"/v1/bundleIds?{query}", None, token)
    if status != 200:
        raise SystemExit(error_text(status, payload))
    matches = [
        item
        for item in payload.get("data") or []
        if (item.get("attributes") or {}).get("identifier") == BUNDLE_ID
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"Expected one bundle id {BUNDLE_ID} in the developer account, found {len(matches)}. "
            "This bootstrap does not create the App ID."
        )
    return str(matches[0]["id"])


def ensure_iap(request, token: str, bundle_resource_id: str) -> None:
    status, payload = request(
        "GET",
        f"/v1/bundleIds/{bundle_resource_id}/bundleIdCapabilities",
        None,
        token,
    )
    if status != 200:
        raise SystemExit(error_text(status, payload))
    enabled = {
        (item.get("attributes") or {}).get("capabilityType") for item in payload.get("data") or []
    }
    if "IN_APP_PURCHASE" in enabled:
        print("In-App Purchase capability: already enabled")
        return
    body = {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": {"capabilityType": "IN_APP_PURCHASE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}}
            },
        }
    }
    status, payload = request("POST", "/v1/bundleIdCapabilities", body, token)
    if status == 409:
        print("In-App Purchase capability: already enabled")
        return
    if status not in (200, 201):
        raise SystemExit(error_text(status, payload))
    print("In-App Purchase capability: enabled")


def delete_named_profiles(request, token: str) -> None:
    query = urllib.parse.urlencode({"filter[profileType]": "IOS_APP_STORE", "limit": "100"})
    status, payload = request("GET", f"/v1/profiles?{query}", None, token)
    if status != 200:
        raise SystemExit(error_text(status, payload))
    for item in payload.get("data") or []:
        name = (item.get("attributes") or {}).get("name")
        if name != PROFILE_NAME:
            continue
        profile_id = item.get("id")
        print(f"Deleting existing App Store profile id={profile_id} name={PROFILE_NAME}")
        status, deleted = request("DELETE", f"/v1/profiles/{profile_id}", None, token)
        if status not in (200, 204):
            raise SystemExit(error_text(status, deleted))


def create_profile(request, token: str, bundle_resource_id: str, certificate_id: str, dest: Path) -> None:
    delete_named_profiles(request, token)
    body = {
        "data": {
            "type": "profiles",
            "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    }
    status, payload = request("POST", "/v1/profiles", body, token)
    if status not in (200, 201):
        raise SystemExit(error_text(status, payload))
    attributes = (payload.get("data") or {}).get("attributes") or {}
    content = attributes.get("profileContent")
    if not content:
        raise SystemExit("App Store Connect did not return profile contents")
    dest.write_bytes(base64.b64decode(content))
    os.chmod(dest, 0o600)
    profile_id = (payload.get("data") or {}).get("id")
    print(f"Created App Store profile id={profile_id} name={PROFILE_NAME}")


def generate_key_and_csr(work: Path, openssl: str) -> tuple[Path, str]:
    key = work / "distribution.key"
    csr = work / "distribution.csr"
    result = subprocess.run(
        [openssl, "genrsa", "-out", str(key), "2048"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise SystemExit("openssl could not generate the distribution key")
    os.chmod(key, 0o600)
    result = subprocess.run(
        [
            openssl,
            "req",
            "-new",
            "-key",
            str(key),
            "-out",
            str(csr),
            "-subj",
            f"/CN=Reincarnated as WHAT CI/OU={TEAM_ID}/O=thongdo/C=US",
        ],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise SystemExit("openssl could not create the certificate signing request")
    return key, csr.read_text()


def create_certificate(request, token: str, csr_pem: str, dest: Path) -> dict[str, str]:
    body = {
        "data": {
            "type": "certificates",
            "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_pem},
        }
    }
    status, payload = request("POST", "/v1/certificates", body, token)
    if status not in (200, 201):
        raise SystemExit(error_text(status, payload))
    item = payload.get("data") or {}
    summary = summarize_cert(item)
    content = (item.get("attributes") or {}).get("certificateContent")
    if not content or not summary["id"]:
        raise SystemExit("App Store Connect did not return the new certificate")
    dest.write_bytes(base64.b64decode(content))
    os.chmod(dest, 0o600)
    print(
        "Created Apple Distribution certificate "
        f"id={summary['id']} expires={summary['expirationDate']} name={summary['displayName']}"
    )
    return summary


def revoke_certificate(request, token: str, certificate_id: str) -> None:
    print(f"Revoking Apple Distribution certificate id={certificate_id}")
    status, payload = request("DELETE", f"/v1/certificates/{certificate_id}", None, token)
    if status not in (200, 204):
        raise SystemExit(error_text(status, payload))


def make_p12(work: Path, key: Path, cert_der: Path, password: str, openssl: str) -> Path:
    pem = work / "cert.pem"
    p12 = work / "distribution.p12"
    password_file = work / "p12-pass.txt"
    password_file.write_text(password)
    os.chmod(password_file, 0o600)
    result = subprocess.run(
        [openssl, "x509", "-inform", "DER", "-in", str(cert_der), "-out", str(pem)],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise SystemExit("openssl could not read the issued certificate")
    result = subprocess.run(
        [
            openssl,
            "pkcs12",
            "-export",
            "-inkey",
            str(key),
            "-in",
            str(pem),
            "-out",
            str(p12),
            "-name",
            "Apple Distribution",
            "-passout",
            f"file:{password_file}",
        ],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise SystemExit("openssl could not write the distribution p12")
    os.chmod(p12, 0o600)
    return p12


def profile_summary(path: Path) -> str:
    try:
        result = subprocess.run(
            ["security", "cms", "-D", "-i", str(path)],
            check=False,
            capture_output=True,
        )
    except FileNotFoundError:
        return "profile written (security cms is not available to print its UUID)"
    if result.returncode != 0:
        return "profile written"
    data = plistlib.loads(result.stdout)
    uuid = data.get("UUID", "")
    name = data.get("Name", "")
    app_id = (data.get("Entitlements") or {}).get("application-identifier", "")
    return f"profile name={name} uuid={uuid} application-identifier={app_id}"


def readme(action: str) -> str:
    common = f"""This archive was written on the machine that ran tools/ios_signing_bootstrap.py.
Do not upload it, or the work directory, to GitHub Actions. The repository is
public, so an artifact would be public.

Decrypt with the password in the export password file:

{DECRYPT_COMMAND}

Do this on any machine with openssl. A Mac is not required.
Delete the work directory and this archive after the secrets are stored, and
revoke the temporary Admin API key.
"""
    if action == "refresh":
        return (
            common
            + """
This bundle only refreshes the App Store provisioning profile. The distribution
certificate was not changed. Update one secret:

  base64 < appstore.mobileprovision | tr -d '\\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64

Profile name: reincarnatedaswhat App Store
"""
        )
    return (
        common
        + """
This bundle is the one Apple Distribution certificate and its App Store profile.
Store these three repository secrets, then delete the Admin API key:

  base64 < distribution.p12 | tr -d '\\n' | gh secret set IOS_DISTRIBUTION_P12_BASE64
  gh secret set IOS_DISTRIBUTION_P12_PASSWORD < p12-password.txt
  base64 < appstore.mobileprovision | tr -d '\\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64

p12-password.txt has no trailing newline. The TestFlight workflow imports that
p12 on every run and does not create another certificate.
Profile name: reincarnatedaswhat App Store
Team: 9589T6378Y
Bundle id: com.thongdo.reincarnatedaswhat
"""
    )


def encrypt_files(files: list[Path], dest: Path, password: str, openssl: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tar_path = Path(tmp) / "bundle.tar.gz"
        password_file = Path(tmp) / "export-password.txt"
        password_file.write_text(password)
        os.chmod(password_file, 0o600)
        with tarfile.open(tar_path, "w:gz") as archive:
            for path in files:
                archive.add(path, arcname=path.name)
        result = subprocess.run(
            [
                openssl,
                "enc",
                "-aes-256-cbc",
                "-pbkdf2",
                "-iter",
                "200000",
                "-salt",
                "-in",
                str(tar_path),
                "-out",
                str(dest),
                "-pass",
                f"file:{password_file}",
            ],
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            raise SystemExit("openssl could not encrypt the signing bundle")
    os.chmod(dest, 0o600)


def run(args: argparse.Namespace, request=default_request) -> None:
    password = Path(args.export_password_file).read_text().strip("\n")
    if len(password) < 16:
        raise SystemExit(
            "The export password file must contain at least 16 characters. "
            "It only encrypts the local bundle. Do not upload that bundle."
        )
    openssl = args.openssl
    token = make_jwt(Path(args.key_path), args.key_id, args.issuer_id, openssl)
    distribution = list_certificates(request, token, "DISTRIBUTION")
    print(format_certs(distribution))
    legacy = list_certificates(request, token, "IOS_DISTRIBUTION")
    if legacy:
        print(
            "Legacy iOS Distribution certificates are present and were left alone. "
            "Xcode 26 signs with Apple Distribution."
        )
        print(format_certs(legacy, "Legacy iOS Distribution certificates"))
    action = decide(distribution, args.confirm, args.revoke_certificate_id or "", args.refresh_profile_only)
    bundle_resource_id = find_bundle(request, token)
    print(f"Bundle id {BUNDLE_ID} resource id={bundle_resource_id}")
    ensure_iap(request, token, bundle_resource_id)

    work = Path(args.work_dir)
    work.mkdir(parents=True, exist_ok=True)
    os.chmod(work, 0o700)
    try:
        profile_path = work / "appstore.mobileprovision"
        files: list[Path]
        if action == "refresh":
            create_profile(request, token, bundle_resource_id, distribution[0]["id"], profile_path)
            readme_path = work / "README.txt"
            readme_path.write_text(readme("refresh"))
            files = [profile_path, readme_path]
        else:
            if action == "revoke_then_create":
                revoke_certificate(request, token, args.revoke_certificate_id.strip())
            key, csr_pem = generate_key_and_csr(work, openssl)
            cert_der = work / "cert.der"
            created = create_certificate(request, token, csr_pem, cert_der)
            # Hex so the password cannot start with a dash and confuse `security import -P`.
            p12_password = os.urandom(24).hex()
            p12 = make_p12(work, key, cert_der, p12_password, openssl)
            password_path = work / "p12-password.txt"
            password_path.write_text(p12_password)
            os.chmod(password_path, 0o600)
            create_profile(request, token, bundle_resource_id, created["id"], profile_path)
            readme_path = work / "README.txt"
            readme_path.write_text(readme("create"))
            files = [p12, password_path, profile_path, readme_path]
        print(profile_summary(profile_path))
        encrypt_files(files, Path(args.output), password, openssl)
    except SystemExit:
        if (work / "distribution.key").is_file() and (work / "cert.der").is_file():
            print(f"Apple already issued the certificate. The private key is still in {work}.")
            print("That directory was not deleted. Apple cannot return the key.")
        raise

    print(f"Encrypted signing bundle: {args.output}")
    print(f"Private key and p12 are in {work}. Delete that directory after the secrets are stored.")
    print("Do not upload the bundle or the work directory. This repository is public.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--key-path", required=True)
    parser.add_argument("--export-password-file", required=True)
    parser.add_argument("--confirm", required=True)
    parser.add_argument("--revoke-certificate-id", default="")
    parser.add_argument("--refresh-profile-only", action="store_true")
    parser.add_argument("--output", default="build/ios-signing-bundle.tar.gz.enc")
    parser.add_argument(
        "--work-dir",
        default="build/ios-signing-work",
        help="Kept on disk if Apple issues a certificate and a later step fails. build/ is gitignored.",
    )
    parser.add_argument("--openssl", default=os.environ.get("IOS_OPENSSL", "openssl"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    run(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
