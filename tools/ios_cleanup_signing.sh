#!/usr/bin/env bash
# Delete API keys, the p12, the profile, and the temporary keychain.
# Safe to run when some of those files were already removed.

set -u

manifest="${RUNNER_TEMP:-/tmp}/ios-signing-manifest.txt"
if [ -f "$manifest" ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rm -rf "$path"
  done <"$manifest"
  rm -f "$manifest"
fi

rm -rf "$HOME/.private_keys" "$HOME/private_keys" "$HOME/.appstoreconnect/private_keys" "${RUNNER_TEMP:-/tmp}/private_keys"
rm -f "${RUNNER_TEMP:-/tmp}"/AuthKey_*.p8 \
  "${RUNNER_TEMP:-/tmp}/distribution.p12" \
  "${RUNNER_TEMP:-/tmp}/appstore.mobileprovision" \
  "${RUNNER_TEMP:-/tmp}/profile.plist" \
  "${RUNNER_TEMP:-/tmp}/profile-meta.txt" \
  "${RUNNER_TEMP:-/tmp}/api-key.p8" \
  "${RUNNER_TEMP:-/tmp}/admin-api-key.p8"

if command -v security >/dev/null 2>&1; then
  security delete-keychain "${RUNNER_TEMP:-/tmp}/app-signing.keychain-db" >/dev/null 2>&1 || true
fi

echo "Signing files removed."
