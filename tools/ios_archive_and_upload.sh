#!/usr/bin/env bash
# Export the Godot iOS Xcode project, archive it with the saved distribution
# certificate, and upload the IPA to TestFlight.
#
# Does not create a certificate or pass -allowProvisioningUpdates. The .p12
# and App Store profile come from repository secrets. The API key is App
# Manager and is used only for the upload.
#
# Bash 3.2 compatible (the bash that ships with macOS).

set -euo pipefail

umask 077

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${GODOT:?GODOT is not set}"
: "${BUILD_NUMBER:?BUILD_NUMBER is not set}"
: "${IOS_SHORT_VERSION:?IOS_SHORT_VERSION is not set}"
: "${TEAM_ID:?TEAM_ID is not set}"
: "${BUNDLE_ID:?BUNDLE_ID is not set}"
: "${ASC_APP_APPLE_ID:?ASC_APP_APPLE_ID is not set}"

require_secret() {
  # Empty check only. The value is unset again and is never printed.
  value="$(printenv "$1" || true)"
  if [ -z "$value" ]; then
    echo "Missing GitHub secret: $1"
    exit 1
  fi
  unset value
}

require_secret APP_STORE_CONNECT_ISSUER_ID
require_secret APP_STORE_CONNECT_KEY_ID
require_secret APP_STORE_CONNECT_API_KEY_P8
require_secret IOS_DISTRIBUTION_P12_BASE64
require_secret IOS_DISTRIBUTION_P12_PASSWORD
require_secret IOS_PROVISIONING_PROFILE_BASE64

case "$APP_STORE_CONNECT_KEY_ID" in
  *[!A-Za-z0-9]*)
    echo "APP_STORE_CONNECT_KEY_ID contains unexpected characters."
    exit 1
    ;;
esac

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/app-signing.keychain-db"
P12_PATH="${RUNNER_TEMP:-/tmp}/distribution.p12"
PROFILE_PATH="${RUNNER_TEMP:-/tmp}/appstore.mobileprovision"
MANIFEST="${RUNNER_TEMP:-/tmp}/ios-signing-manifest.txt"
key_dirs=("$HOME/.private_keys" "$HOME/private_keys" "$HOME/.appstoreconnect/private_keys")
: >"$MANIFEST"
printf '%s\n' "$KEYCHAIN_PATH" "$P12_PATH" "$PROFILE_PATH" >>"$MANIFEST"

cleanup() {
  status=$?
  trap - EXIT
  bash "$ROOT/tools/ios_cleanup_signing.sh" || true
  exit "$status"
}
trap cleanup EXIT

python3 tools/write_secret_file.py pem APP_STORE_CONNECT_API_KEY_P8 "${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
API_KEY_FILE="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
printf '%s\n' "$API_KEY_FILE" >>"$MANIFEST"
for dir in "${key_dirs[@]}"; do
  mkdir -p "$dir"
  chmod 700 "$dir"
  cp "$API_KEY_FILE" "$dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  chmod 600 "$dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
done

python3 tools/write_secret_file.py b64 IOS_DISTRIBUTION_P12_BASE64 "$P12_PATH"
python3 tools/write_secret_file.py b64 IOS_PROVISIONING_PROFILE_BASE64 "$PROFILE_PATH"
case "$IOS_DISTRIBUTION_P12_PASSWORD" in
  -*)
    echo "IOS_DISTRIBUTION_P12_PASSWORD must not start with a dash. Generate a new p12 with the bootstrap workflow."
    exit 1
    ;;
esac

KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" "/Library/Keychains/System.keychain"
security default-keychain -s "$KEYCHAIN_PATH"
security import "$P12_PATH" -k "$KEYCHAIN_PATH" -P "$IOS_DISTRIBUTION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcodebuild
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -q "Apple Distribution"; then
  echo "The p12 did not contain an Apple Distribution identity."
  exit 1
fi
echo "Distribution identity is in the temporary keychain."

PROFILE_META="${RUNNER_TEMP:-/tmp}/profile-meta.txt"
security cms -D -i "$PROFILE_PATH" >"${RUNNER_TEMP:-/tmp}/profile.plist"
python3 - "$TEAM_ID" "$BUNDLE_ID" "${RUNNER_TEMP:-/tmp}/profile.plist" "$PROFILE_META" <<'PY'
import plistlib
import sys

team_id, bundle_id, plist_path, out_path = sys.argv[1:]
with open(plist_path, "rb") as handle:
    data = plistlib.load(handle)
name = data.get("Name") or ""
uuid = data.get("UUID") or ""
entitlements = data.get("Entitlements") or {}
app_id = entitlements.get("application-identifier") or ""
expected = team_id + "." + bundle_id
if app_id != expected:
    raise SystemExit("provisioning profile application-identifier is %s, expected %s" % (app_id, expected))
if "ProvisionedDevices" in data:
    raise SystemExit("provisioning profile lists devices, so it is not an App Store profile")
if not name or not uuid:
    raise SystemExit("provisioning profile is missing Name or UUID")
def shell_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"
with open(out_path, "w", encoding="utf-8") as handle:
    handle.write("PROFILE_NAME=%s\nPROFILE_UUID=%s\n" % (shell_quote(name), shell_quote(uuid)))
print("profile name=%s uuid=%s" % (name, uuid))
PY
rm -f "${RUNNER_TEMP:-/tmp}/profile.plist"
# shellcheck disable=SC1090
. "$PROFILE_META"
rm -f "$PROFILE_META"

PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILE_DIR"
cp "$PROFILE_PATH" "$PROFILE_DIR/${PROFILE_UUID}.mobileprovision"
chmod 600 "$PROFILE_DIR/${PROFILE_UUID}.mobileprovision"
printf '%s\n' "$PROFILE_DIR/${PROFILE_UUID}.mobileprovision" >>"$MANIFEST"

export GODOT_APPLE_PLATFORM_PROFILE_SPECIFIER_RELEASE="$PROFILE_NAME"

mkdir -p build/ios
echo "Building the iOS share sheet plugin."
bash "$ROOT/tools/build_ios_share_plugin.sh"

echo "Importing the Godot project."
"$GODOT" --headless --path . --import --quit

echo "Exporting the iOS Xcode project."
export_log="${RUNNER_TEMP:-/tmp}/godot-ios-export.log"
set +e
"$GODOT" --headless --path . --export-release "iOS" build/ios/reincarnated.ipa >"$export_log" 2>&1
export_status=$?
set -e
cat "$export_log"
if [ "$export_status" -ne 0 ]; then
  echo "Godot iOS export failed."
  exit "$export_status"
fi
if grep -E "SCRIPT ERROR|iOS library binary not found|Export template not found|dylibs_dir.is_null" "$export_log"; then
  echo "Godot iOS export reported an error."
  exit 1
fi

python3 tools/patch_admob_spm.py build/ios/reincarnated.ipa

pbxproj="build/ios/reincarnated.xcodeproj/project.pbxproj"
info_plist="build/ios/reincarnated/reincarnated-Info.plist"
require_text() {
  if ! grep -F -q "$2" "$1"; then
    echo "Expected ${3} in ${1}"
    exit 1
  fi
}
test -f "$pbxproj"
test -f "$info_plist"
require_text "$pbxproj" "MARKETING_VERSION = ${IOS_SHORT_VERSION};" "store version ${IOS_SHORT_VERSION}"
require_text "$pbxproj" "CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};" "build number ${BUILD_NUMBER}"
require_text "$pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID};" "bundle id"
require_text "$info_plist" "GADApplicationIdentifier" "AdMob app id"
require_text "$info_plist" "ca-app-pub-1397621797560860~9031599553" "real iOS AdMob app id"
require_text "$info_plist" "NSUserTrackingUsageDescription" "tracking usage description"
require_text "$info_plist" "Ask App Not to Track" "tracking prompt copy"
require_text "$info_plist" "SKAdNetworkItems" "AdMob SKAdNetwork list"
require_text "$info_plist" "cstr6suwn9.skadnetwork" "Google SKAdNetwork id"
require_text "$info_plist" "UIInterfaceOrientationLandscapeLeft" "landscape left"
require_text "$info_plist" "UIInterfaceOrientationLandscapeRight" "landscape right"
if grep -q "UIInterfaceOrientationPortrait" "$info_plist"; then
  echo "iPhone build should stay landscape."
  exit 1
fi
require_text "$pbxproj" 'TARGETED_DEVICE_FAMILY = "1";' "iPhone only"
if grep -q 'TARGETED_DEVICE_FAMILY = "1,2";' "$pbxproj"; then
  echo "iPhone build should not include iPad."
  exit 1
fi
privacy_plist="$(find build/ios -name 'PrivacyInfo.xcprivacy' -print -quit)"
if [ -z "$privacy_plist" ]; then
  echo "Expected PrivacyInfo.xcprivacy in the iOS export."
  exit 1
fi
require_text "$privacy_plist" "NSPrivacyTracking" "privacy manifest tracking flag"
python3 - "$privacy_plist" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
key = "<key>NSPrivacyTracking</key>"
start = text.find(key)
window = text[start:start + 80] if start >= 0 else ""
if "<true/>" not in window:
    raise SystemExit("PrivacyInfo.xcprivacy should set NSPrivacyTracking to true")
PY
require_text "$privacy_plist" "NSPrivacyAccessedAPICategoryFileTimestamp" "file timestamp reason"
require_text "$privacy_plist" "DDA9.1" "file timestamp reason code"
require_text "$privacy_plist" "C617.1" "file timestamp container reason"
require_text "$privacy_plist" "NSPrivacyAccessedAPICategoryDiskSpace" "disk space reason"
require_text "$privacy_plist" "E174.1" "disk space reason code"
require_text "$privacy_plist" "NSPrivacyAccessedAPICategorySystemBootTime" "boot time reason"
require_text "$privacy_plist" "35F9.1" "boot time reason code"
require_text "$privacy_plist" "NSPrivacyAccessedAPICategoryUserDefaults" "user defaults reason"
require_text "$privacy_plist" "CA92.1" "user defaults reason code"
require_text "$pbxproj" "PoingGodotAdMobDeps" "AdMob Swift package"
test -f build/ios/admob_spm/Package.swift
echo "Xcode project has version ${IOS_SHORT_VERSION} (${BUILD_NUMBER}), AdMob, and the tracking prompt."

python3 tools/ios_export_options.py \
  --output build/ios/ExportOptions.plist \
  --team-id "$TEAM_ID" \
  --bundle-id "$BUNDLE_ID" \
  --profile-name "$PROFILE_NAME"

archive="build/ios/reincarnated.xcarchive"
rm -rf "$archive"
echo "Archiving with manual signing."
xcodebuild \
  -project build/ios/reincarnated.xcodeproj \
  -scheme reincarnated \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -archivePath "$archive" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  archive \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  "CODE_SIGN_IDENTITY=Apple Distribution" \
  "PROVISIONING_PROFILE_SPECIFIER=${PROFILE_NAME}" \
  "PROVISIONING_PROFILE=${PROFILE_UUID}" \
  MARKETING_VERSION="$IOS_SHORT_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "Exporting the App Store IPA."
rm -rf build/ios/export
xcodebuild \
  -exportArchive \
  -archivePath "$archive" \
  -exportPath build/ios/export \
  -exportOptionsPlist build/ios/ExportOptions.plist

ipa=""
for candidate in build/ios/export/*.ipa; do
  ipa="$candidate"
  break
done
if [ -z "$ipa" ] || [ ! -f "$ipa" ]; then
  echo "xcodebuild did not write an IPA."
  exit 1
fi
echo "IPA: $ipa"

help_file="${RUNNER_TEMP:-/tmp}/altool-help.txt"
xcrun altool --help >"$help_file" 2>&1 || true
if grep -q -- "--upload-package" "$help_file"; then
  upload_mode="package"
elif grep -q -- "--upload-app" "$help_file"; then
  upload_mode="app"
else
  echo "xcrun altool has neither --upload-package nor --upload-app."
  exit 1
fi
if grep -q -- "--api-key" "$help_file"; then
  api_key_flag="--api-key"
  api_issuer_flag="--api-issuer"
else
  api_key_flag="--apiKey"
  api_issuer_flag="--apiIssuer"
fi

echo "Uploading to TestFlight (App Store Connect app ${ASC_APP_APPLE_ID})."
if [ "$upload_mode" = "package" ]; then
  xcrun altool \
    --upload-package "$ipa" \
    --type ios \
    --apple-id "$ASC_APP_APPLE_ID" \
    --bundle-id "$BUNDLE_ID" \
    --bundle-version "$BUILD_NUMBER" \
    --bundle-short-version-string "$IOS_SHORT_VERSION" \
    "$api_key_flag" "$APP_STORE_CONNECT_KEY_ID" \
    "$api_issuer_flag" "$APP_STORE_CONNECT_ISSUER_ID"
else
  xcrun altool \
    --upload-app \
    -f "$ipa" \
    -t ios \
    "$api_key_flag" "$APP_STORE_CONNECT_KEY_ID" \
    "$api_issuer_flag" "$APP_STORE_CONNECT_ISSUER_ID"
fi

echo "Upload finished. TestFlight still has to process the build."
