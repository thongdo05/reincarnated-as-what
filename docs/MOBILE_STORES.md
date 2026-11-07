# iOS and Android

The web build is still the one GitHub Pages ships. Ads and the remove-ads purchase do nothing on the web and in the editor. On a phone, dev builds and a TestFlight run that leaves **Use real AdMob unit ids** unchecked request Google's test ad units. `USE_TEST_ADS` in `scripts/store_config.gd` stays `true` in git. The AdMob app id in the binary is the real one either way.

Support email: `playreincarnated@gmail.com`. The game does not collect the player's email. That address is the contact on the public privacy and support pages (`privacy.html` and `support.html` on the Pages site). A request to delete a leaderboard row is an email to that address. There is no in-game account.

Landscape only. The project setting `display/window/handheld/orientation` is sensor landscape, so the phone may lie on either side and never in portrait. Dragging still moves the ship: touch is `InputEventScreenTouch` / `InputEventScreenDrag`, and the pause target stays at least 44 points, inset by the notch when the phone has one.

## Plugins

- **Ads:** [Poing Studios AdMob](https://github.com/poingstudios/godot-admob-plugin) v5.1.0. It is the current Godot 4 AdMob plugin with a single GDScript API for Android and iOS, and this release ships export binaries built for Godot 4.7.2. Vendored under `addons/admob` with the ads module only (no mediation networks).
- **Android purchases:** [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) 3.3.0, from the Godot Foundation. Play Billing library 9.1. It loads on Godot 4.7.2.
- **iOS purchases:** [godot_ios_plugin_iap](https://github.com/hrk4649/godot_ios_plugin_iap) 0.4.0 (StoreKit, built for Godot 4.7). The official `godot-storekit2` release stops at Godot 4.6.
- **App Tracking Transparency:** [godot-ios-att](https://github.com/Seneku/godot-ios-att) v0.1.0. The published binary is built for Godot 4.7.1. This project exports with 4.7.2. If Xcode fails to link `GodotIosAtt`, rebuild that plugin against 4.7.2 and replace `ios/plugins/godot-ios-att`.
- **Share sheet:** `ios/plugins/share_sheet/`. A small Objective-C++ plugin (`share_sheet.mm`) presents `UIActivityViewController` with the share text, the challenge link, and the PNG. It does not link Godot headers. `tools/build_ios_share_plugin.sh` compiles the xcframework with the iOS SDK. The TestFlight workflow runs that script before export. No extra secrets. On a Mac, run the script once before exporting iOS. The plugin is on in the iOS preset as `ShareSheet`. Android uses the engine's `AndroidRuntime` share intent instead of a plugin. Web still uses `shareRunCard` in the page shell.

The prompt text is `StoreConfig.ATT_USAGE_DESCRIPTION`. The export plugin writes it to Info.plist as `NSUserTrackingUsageDescription`. Godot's `privacy/tracking_enabled` flag is a different key (the privacy manifest) and does not show the prompt by itself.

## One config file

`scripts/store_config.gd`

- `USE_TEST_ADS` defaults to `true`. Dev builds, and a TestFlight run with the box unchecked, request Google's sample ad units. Real interstitial and rewarded units are already in this file and are used only when the flag is `false`.
- The real AdMob app ids are filled in. Export always writes those into Info.plist (`GADApplicationIdentifier`) and the Android manifest (`com.google.android.gms.ads.APPLICATION_ID`), including while test units are on.
- Banner real unit ids stay empty. A real-ads build therefore does not request a banner. Test-ads builds still use Google's sample banner.
- Rewarded real units are filled: iOS `ca-app-pub-1397621797560860/3491799585`, Android `ca-app-pub-1397621797560860/6919908709`. **Watch ad: choose your form** loads whichever rewarded unit `rewarded_unit_id()` returns.
- Privacy and support URLs live here too (`PRIVACY_URL`, `SUPPORT_URL`). The pause screen on iOS and Android opens them in the system browser.
- `remove_ads` is the product id. It is already created in App Store Connect as a non-consumable. The $2.99 price is set in the stores, not in code.

Do not flip `USE_TEST_ADS` in git for a TestFlight upload. Use the workflow input below. A local Mac archive that should serve real units can set the flag to `false`, export, then set it back before committing.

## Build the iOS app on a Mac

Godot 4.7.2, Xcode 15 or newer, and an Apple Developer account.

1. Install the matching Godot export templates (`4.7.2.stable`). Godot refuses the iOS export until Project Settings → Rendering → Textures → VRAM Compression → Import ETC2 ASTC is on. The textures themselves stay lossless. The TestFlight workflow turns that setting on in the runner's copy of `project.godot` and does not commit it, so the web export is unchanged.
2. Open this folder in Godot. Project → Export → iOS. The preset is already filled in:
   - Name: `Reincarnated as WHAT?!`
   - Bundle id: `com.thongdo.reincarnatedaswhat`
   - iPhone only, landscape, minimum iOS 15
   - Icon: `res://app_icon/app_icon_1024.png` (Godot downsizes it). Home screen also uses `app_icon_180.png`.
   - Plugins `IOSInAppPurchase`, `godot-ios-att`, and `ShareSheet` are on. Build the share plugin first: `bash tools/build_ios_share_plugin.sh`.
   - Team ID `9589T6378Y` is already in the preset (`application/app_store_team_id`). Leave the provisioning fields empty if Xcode will sign automatically.
   - Export Project Only is on, so Godot writes an Xcode project and does not try to sign an IPA.
3. Leave `USE_TEST_ADS` as `true` in `scripts/store_config.gd` for this build. The export still writes the real iOS AdMob app id `ca-app-pub-1397621797560860~9031599553` into Info.plist as `GADApplicationIdentifier`. Requests use Google's test ad units.
4. Export to `build/ios/reincarnated.ipa`. Godot creates `build/ios/` with the Xcode project.
5. Open that `.xcodeproj` in Xcode.
6. Select the app target. Signing & Capabilities: team `9589T6378Y`, Automatically manage signing. Add the **In-App Purchase** capability. The product id is `remove_ads`.
7. Pick your iPhone (the StoreKit plugin is unreliable in the Simulator) and press Run.
8. The first launch asks for tracking, then the game. With the flag on, the ads are Google's test ads and do not earn money.
9. For TestFlight from a Mac, keep `USE_TEST_ADS` true, set Export Project Only off, keep Release export method on App Store, and archive from Xcode (Product → Archive → Distribute). The store version on the preset is `1.0` (`application/short_version`). The build number (`application/version`) stays `1` for a local archive. Without a Mac, use the GitHub Actions workflow in the next section.
10. For a local archive that should serve the real interstitial and the real rewarded unit, set `USE_TEST_ADS` to `false`, export again, then archive. Set it back to `true` before you commit. Banner real ids are empty, so that build does not show a banner. The GitHub Actions path does the same flip without a commit: check **Use real AdMob unit ids**.

## TestFlight from GitHub Actions

No Mac. Actions → **iOS TestFlight** → Run workflow. The workflow is `workflow_dispatch` only. It does not run on push or on a pull request, and it does not change the web export or `.github/workflows/pages.yml`.

The runner is a GitHub-hosted `macos-26` machine with Xcode 26, which is what App Store Connect currently requires for an iOS upload. It installs Godot 4.7.2 and the matching export templates, checks the vendored AdMob, StoreKit, and ATT release libraries (and downloads the AdMob ads xcframework only if that file is missing), compiles the share-sheet plugin with `tools/build_ios_share_plugin.sh`, exports the Xcode project, archives it, and uploads the IPA to the existing App Store Connect app `6831784046`.

- Store version stays **1.0**. The build number is `github.run_number` for that workflow, so a second upload does not reuse build 1. The first successful run is build 1. If a build with that number was already uploaded, run the workflow again.
- `USE_TEST_ADS` stays `true` unless you check **Use real AdMob unit ids** (`use_real_ads`, default off). That checkbox edits the runner's copy of `scripts/store_config.gd` for that build only. It is not committed. Checked, the build requests the real interstitial and the real rewarded unit. Real banner ids are empty, so the banner stays off. Unchecked, every format stays on Google's sample units, which is what an existing run does if you leave the box alone.
- The upload uses `xcrun altool` with the App Manager API key. The `.p8` is written to a temp file mode `0600` and deleted at the end, including when the job fails. The log does not print it.

### Signing

Signing is already done, outside CI. The Apple Distribution certificate is `8S3BW29TWP`. The App Store profile is `reincarnatedaswhat App Store` (`6KJ54JLQ6U`). They were created by running `tools/ios_signing_bootstrap.py` locally with a temporary Admin API key. That key is not a repository secret.

The TestFlight workflow does not create a certificate. Apple allows one Apple Distribution certificate per team, and it will not give the private key back. A new runner has an empty keychain, so Xcode's `-allowProvisioningUpdates` would ask Apple for a new certificate on every run. An App Manager key cannot create certificates or profiles anyway.

Each TestFlight run installs the saved `.p12` and the saved App Store profile into a temporary keychain and signs manually (`CODE_SIGN_STYLE=Manual`, no `-allowProvisioningUpdates`). It reads exactly these six secrets:

| Secret | What it is |
| --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID at the top of App Store Connect → Users and Access → Integrations → Team Keys. |
| `APP_STORE_CONNECT_KEY_ID` | Key ID of the App Manager key. |
| `APP_STORE_CONNECT_API_KEY_P8` | Raw contents of that key's `AuthKey_XXXX.p8`, including the `BEGIN PRIVATE KEY` line. Not base64. |
| `IOS_DISTRIBUTION_P12_BASE64` | Base64 of the distribution `.p12`. |
| `IOS_DISTRIBUTION_P12_PASSWORD` | Password for that `.p12`. One line, no leading dash. |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 of the App Store `.mobileprovision`. |

There is no Actions workflow for the bootstrap. Do not upload the `.p12`, the profile, or the work directory as an artifact. This repository is public, so an artifact would be public.

`tools/ios_signing_bootstrap.py` stays in the repo as a local tool for the day the certificate has to be replaced. Create a temporary Admin Team key, download its `.p8` once, and run it on your own machine. Revoke that Admin key when you are done. Do not store the Admin key in GitHub secrets.

```bash
python3 tools/ios_signing_bootstrap.py \
  --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
  --key-id "$ADMIN_KEY_ID" \
  --key-path ./AuthKey_ADMIN.p8 \
  --export-password-file ./export-password.txt \
  --confirm REVOKE-AND-CREATE-ONE-DISTRIBUTION-CERT \
  --revoke-certificate-id 8S3BW29TWP \
  --work-dir build/ios-signing-work
```

`build/` is gitignored. `--work-dir` is not deleted if Apple issues the certificate and a later step fails, so `distribution.key` is still on disk. A first certificate, when the team has none, uses `--confirm CREATE-ONE-DISTRIBUTION-CERT` and omits `--revoke-certificate-id`. Replacing only the profile uses `--refresh-profile-only` and `--confirm REFRESH-APP-STORE-PROFILE`. Then update the three signing secrets from that directory and delete it.

`godot-ios-att` is still the 4.7.1 binary. If the Xcode log says it cannot link `GodotIosAtt`, rebuild that plugin for 4.7.2 and replace `ios/plugins/godot-ios-att`. The workflow does not rebuild it.

## Build the Android app

Godot 4.7.2, Android SDK, and a JDK that matches the Godot 4.7 Android docs. The preset uses the Gradle build, which the AdMob and Play Billing plugins need.

1. Install Android export templates and, in Godot, Project → Install Android Build Template if the export dialog asks.
2. Project → Export → Android. The preset is:
   - Package: `com.thongdo.reincarnatedaswhat`
   - Name: `Reincarnated as WHAT?!`
   - Min SDK 24, arm64-v8a, landscape
   - Adaptive icons from `app_icon/android_adaptive_foreground_432.png` and `android_adaptive_background_432.png`
   - Export format: AAB (`build/android/reincarnated.aab`) for Play
3. Leave `USE_TEST_ADS` true. Export still writes the real Android AdMob app id `ca-app-pub-1397621797560860~1097269219` into the manifest. Requests use Google's test ad units. Set the flag to `false` and export again only when the build should serve the real interstitial and the real rewarded unit. Banner real ids are empty, so that build does not show a banner. Set the flag back to `true` before you commit.
4. For a cable install, switch Export Format to APK and set the path to `build/android/reincarnated.apk`. Debug exports use Godot's debug keystore. Release exports need a keystore filled in on the preset (do not commit the passwords; Godot keeps those in `export_credentials.cfg`, which is gitignored).
5. Install the APK, or upload the AAB to Play Console's internal testing track. Billing and real ads only work on a build Play signed, installed from a testing track, with a license tester account.

## What to create in the consoles

App ids, interstitial units, and rewarded units are already in `scripts/store_config.gd`. Banner real units are not, on purpose.

### AdMob

1. The Android app id `ca-app-pub-1397621797560860~1097269219` is `REAL_ANDROID_APP_ID`. Export writes it into the manifest as `com.google.android.gms.ads.APPLICATION_ID`.
2. The iOS app id `ca-app-pub-1397621797560860~9031599553` is `REAL_IOS_APP_ID`. Export writes it into Info.plist as `GADApplicationIdentifier`.
3. Interstitial units are filled: Android `ca-app-pub-1397621797560860/3747483284`, iOS `ca-app-pub-1397621797560860/3293196875`. They are requested only when `USE_TEST_ADS` is `false`.
4. Rewarded units are filled: Android `ca-app-pub-1397621797560860/6919908709`, iOS `ca-app-pub-1397621797560860/3491799585`. **Watch ad: choose your form** requests the sample rewarded unit while `USE_TEST_ADS` is true, and these units when it is false. Buying `remove_ads` still opens the picker with no ad.
5. Banner real units stay empty (`REAL_ANDROID_BANNER_UNIT_ID`, `REAL_IOS_BANNER_UNIT_ID`). A real-ads build does not request a banner. Paste an id here later only when a real banner should ship.
5. Privacy & messaging: create a GDPR / EEA message so the UMP form can show in Europe. Do not also create an IDFA message there. The game already shows Apple's tracking prompt after the GDPR form, and a second message would ask twice.

### app-ads.txt

Not published. Do not add this file to the GitHub Pages site yet. When AdMob should crawl it, host this single line at `https://<the-domain-registered-in-AdMob>/app-ads.txt`:

```
google.com, pub-1397621797560860, DIRECT, f08c47fec0942fa0
```

### App Store Connect

1. New app. Name `Reincarnated as WHAT?!`. Bundle id `com.thongdo.reincarnatedaswhat` (register the id under Certificates, Identifiers & Profiles first, with In-App Purchase enabled).
2. The non-consumable `remove_ads` is already created in App Store Connect. Price $2.99. The game already uses that product id.
3. The app already has a Restore button on the pause menu and on the card after the first interstitial. Apple requires that.
4. App Privacy labels: see below.
5. Age rating: frequent cartoon violence is already in the game. Ads are interstitials between runs. Answer the ads questions as third-party advertising, unrestricted, not designed for children.

### Google Play Console

1. Create the app. Package name `com.thongdo.reincarnatedaswhat`. Default language whatever you list the store page in. App name `Reincarnated as WHAT?!`.
2. Monetize → Products → In-app products → one-time product. Product id exactly `remove_ads`. Price $2.99. Activate it.
3. Internal testing track, upload the AAB, add your account as a license tester. Play Billing will not complete a purchase on a sideloaded APK.
4. Data safety form: see below.
5. Ads declaration: yes, the app contains ads. After a tester buys remove ads, the banner and the interstitial stop. Choosing a form no longer asks for an ad.

## When ads show

Phone builds only. The web build never loads AdMob and has no form-pick button.

- **Banner.** An adaptive banner on the death card, along the bottom of the safe area, so the score and the buttons stay above it. It hides when the next run starts, while the leaderboard is open, and while a full-screen ad is up. It is never on screen during play.
- **Interstitial.** Full screen, only after death, and only once the player asks for the next run. Not during the first five completed runs. The first chance is between run 5 and run 6, then between 10 and 11, 15 and 16, and so on. Not during a boss fight. If it is not loaded, the next run starts anyway.
- **Rewarded.** The death card has **Watch ad: choose your form**. There is no limit. The picker opens only when the reward callback fires. The player can pick Slime, Goblin, Vending Machine, Cat, or Demon Lord. Dragon is not in the list. That pick is the next run only. The daily index still advances, so the run after that is the normal random roll again, and that roll still will not repeat the form they just played. If the ad fails or they skip it, the picker stays closed and the next form is the normal roll. **Keep random** on the picker does the same.
- Buying `remove_ads` removes the banner and the interstitial. The death-card button becomes **Choose your form** and opens the picker with no ad. Restore still works. A later refund, once the store query says the product is gone, turns the ads back on.

The pause menu has **Remove ads** and **Restore**. On iOS and Android it also has **Privacy** and **Support**, just above that bar. They open `PRIVACY_URL` and `SUPPORT_URL` in the system browser. The web and CrazyGames pause screens do not show them. After the first interstitial that actually plays, the same remove-ads offer appears before the next run, with **Not now**.

App Store Connect and Play Console still want those same URLs in the listing. The in-app row is the copy a player can open without leaving the pause screen. There is no account screen, so the pause screen is the place the store rules ask for.

## What the game collects

Three things, and nothing else. No email, phone number, contacts, photos, precise location, or health data.

1. **Ads.** Google AdMob, only on the iOS and Android builds: a death-card banner, an interstitial every five runs, and an optional rewarded ad to choose the next form. Google receives the advertising identifier and related device data. If the player taps Ask App Not to Track, iOS does not give AdMob the advertising identifier. Buying `remove_ads` stops the banner and the interstitial. The web build does not load AdMob.
2. **Remove ads.** The purchase is handled by Apple (StoreKit) or Google Play. The game keeps a local flag that ads are removed. It does not send the receipt or the payment to our server.
3. **Leaderboard.** The name the player chooses and their scores are stored in Supabase (`scripts/leaderboard.gd`). The same row includes how long the run lasted, which form it was, and a random id the game creates so that device keeps its row. That id is not the advertising identifier. It is stored on the device and sent only with the leaderboard. To ask for that row to be deleted, email `playreincarnated@gmail.com` with the leaderboard name.

## Privacy labels

Use the list above when you fill the forms. The binary privacy manifest (device id and advertising data, third-party advertising, tracking) covers AdMob only.

### App Store (App Privacy)

- **Data used to track you:** Device ID and Advertising Data, from AdMob, when the player allows tracking.
- **Identifiers:** the advertising identifier and device data AdMob collects, for third-party advertising and tracking. Also the random leaderboard id, linked to the player's chosen name and scores, for app functionality, not for tracking.
- **Name and gameplay:** the leaderboard name and scores (and the run length and form on that row), stored in Supabase, for app functionality. Not used to track the player across other companies' apps.
- **Purchases:** Apple processes `remove_ads`. Declare purchase history only if the form requires it for a StoreKit purchase. We do not receive the receipt.
- **Diagnostics:** this project does not add a crash SDK. If the merged `PrivacyInfo.xcprivacy` in the Xcode archive lists crash or performance data from Google's SDK, declare those as diagnostics, not linked, not used for tracking.

### Play Console (Data safety)

- **Device or other IDs:** the advertising id and device data, collected and shared with Google for advertising. Separately, the random leaderboard id, collected and stored in Supabase with the score row, for app functionality.
- **App activity:** scores, form, and run length, stored in Supabase. AdMob may also collect ad interactions and share them with Google for advertising.
- **Name:** the leaderboard name the player types, stored in Supabase.
- **Financial info:** Google Play processes `remove_ads`. The app does not collect the card or the receipt.
- Data is encrypted in transit.
- There is no account to delete. Players can reset the advertising id in Android settings, and they can choose another leaderboard name on the device.
- Data is not sold.

## iOS export checklist

Godot writes these at export time. The TestFlight script checks the generated Xcode project before it archives.

- **Tracking prompt.** `StoreConfig.ATT_USAGE_DESCRIPTION` is written to Info.plist as `NSUserTrackingUsageDescription` by `addons/raw_store`. The game calls `GodotIosAtt.request_tracking_authorization()` on iOS, so the string has to be there.
- **AdMob app id.** `GADApplicationIdentifier` is the real iOS app id `ca-app-pub-1397621797560860~9031599553`, including on a test-ads build.
- **SKAdNetwork.** The AdMob iOS exporter copies Google's buyer list from `addons/admob/ios/bin/ads/poing_godot_admob_ads.gd` into Info.plist, including Google's `cstr6suwn9.skadnetwork`. No mediation networks are enabled, so no extra partner ids are required.
- **Privacy manifest.** Godot generates `PrivacyInfo.xcprivacy` from the iOS preset. Tracking is on, with the Google ad domains. Collected data is device id and advertising data for third-party advertising. Required-reason APIs are file timestamp (`DDA9.1`, `C617.1`), disk space (`E174.1`), boot time (`35F9.1`), and user defaults (`CA92.1`). The AdMob plugin static library calls `NSUserDefaults` and is linked into the app, so the app manifest has to name that category. Google's own SDK ships a separate manifest inside the Swift package.
- **iPhone only, landscape.** `application/targeted_device_family=0` is iPhone (`TARGETED_DEVICE_FAMILY = 1`). `display/window/handheld/orientation=4` is sensor landscape, so Info.plist lists landscape left and landscape right and not portrait.

## What was not run here

Linux CI can export the web build and run the headless smoke test. It cannot compile the Xcode project or the Android Gradle project, and it cannot show a test ad or complete a sandbox purchase. Those steps are the Mac and device passes above.

The TestFlight workflow was not run from this environment, so nothing was archived with Xcode or uploaded. The distribution certificate `8S3BW29TWP` and the profile `reincarnatedaswhat App Store` (`6KJ54JLQ6U`) were created locally. `tools/test_ios_ci.py` checks the version edit, the AdMob Swift package patch, the local signing bundle, and that the TestFlight workflow uses only the six signing secrets. A headless Godot 4.7.2 export of the iOS Xcode project on Linux checks that the project, the version, and the AdMob package are written. It does not run `xcodebuild`.
