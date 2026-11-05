# iOS and Android

The web build is still the one GitHub Pages ships. Ads and the remove-ads purchase do nothing on the web and in the editor. On a phone they use test ads until `scripts/store_config.gd` says otherwise.

Landscape only. The project setting `display/window/handheld/orientation` is sensor landscape, so the phone may lie on either side and never in portrait. Dragging still moves the ship: touch is `InputEventScreenTouch` / `InputEventScreenDrag`, and the pause target stays at least 44 points, inset by the notch when the phone has one.

## Plugins

- **Ads:** [Poing Studios AdMob](https://github.com/poingstudios/godot-admob-plugin) v5.1.0. It is the current Godot 4 AdMob plugin with a single GDScript API for Android and iOS, and this release ships export binaries built for Godot 4.7.2. Vendored under `addons/admob` with the ads module only (no mediation networks).
- **Android purchases:** [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) 3.3.0, from the Godot Foundation. Play Billing library 9.1. It loads on Godot 4.7.2.
- **iOS purchases:** [godot_ios_plugin_iap](https://github.com/hrk4649/godot_ios_plugin_iap) 0.4.0 (StoreKit, built for Godot 4.7). The official `godot-storekit2` release stops at Godot 4.6.
- **App Tracking Transparency:** [godot-ios-att](https://github.com/Seneku/godot-ios-att) v0.1.0. The published binary is built for Godot 4.7.1. This project exports with 4.7.2. If Xcode fails to link `GodotIosAtt`, rebuild that plugin against 4.7.2 and replace `ios/plugins/godot-ios-att`.

The prompt text is `StoreConfig.ATT_USAGE_DESCRIPTION`. The export plugin writes it to Info.plist as `NSUserTrackingUsageDescription`. Godot's `privacy/tracking_enabled` flag is a different key (the privacy manifest) and does not show the prompt by itself.

## One config file

`scripts/store_config.gd`

- `USE_TEST_ADS` defaults to `true`. Test ad units are Google's public samples.
- Real app ids and ad unit ids are the empty strings in that file. Paste them there. Do not put them in a second file.
- On export, `addons/raw_store` copies the app id (the one with `~`) into the AdMob project settings that the Poing exporter bakes into the manifest and Info.plist.
- Ad unit ids (the ones with `/`) are read at runtime from the same file.
- `remove_ads` is the product id. The $2.99 price is set in the stores, not in code. The button shows the store's localized price once the store returns it.

A store build that should earn money sets `USE_TEST_ADS` to `false` and fills the real ids. Exporting with the flag off and an empty app id stops with an error.

## Build the iOS app on a Mac

Godot 4.7.2, Xcode 15 or newer, and an Apple Developer account.

1. Install the matching Godot export templates (`4.7.2.stable`).
2. Open this folder in Godot. Project → Export → iOS. The preset is already filled in:
   - Name: `Reincarnated as WHAT?!`
   - Bundle id: `com.thongdo.reincarnatedaswhat` (change it here and in App Store Connect if you want a different one)
   - iPhone only, landscape, minimum iOS 15
   - Icon: `res://app_icon/app_icon_1024.png` (Godot downsizes it). Home screen also uses `app_icon_180.png`.
   - Plugins `IOSInAppPurchase` and `godot-ios-att` are on.
   - Export Project Only is on, so Godot writes an Xcode project and does not try to sign an IPA.
3. Put your Team ID in the iOS preset (`application/app_store_team_id`). Leave the provisioning fields empty if Xcode will sign automatically.
4. Export to `build/ios/reincarnated.ipa`. Godot creates `build/ios/` with the Xcode project.
5. Open that `.xcodeproj` in Xcode.
6. Select the app target. Signing & Capabilities: your team, Automatically manage signing. Add the **In-App Purchase** capability.
7. Pick your iPhone (the StoreKit plugin is unreliable in the Simulator) and press Run.
8. The first launch asks for tracking, then the game. Ads between runs use Google's test ads while `USE_TEST_ADS` is true. Test ads do not earn money.
9. For TestFlight or the App Store, in the iOS preset set Export Project Only off, Export Method Release to App Store, and archive from Xcode (Product → Archive → Distribute).

## Build the Android app

Godot 4.7.2, Android SDK, and a JDK that matches the Godot 4.7 Android docs. The preset uses the Gradle build, which the AdMob and Play Billing plugins need.

1. Install Android export templates and, in Godot, Project → Install Android Build Template if the export dialog asks.
2. Project → Export → Android. The preset is:
   - Package: `com.thongdo.reincarnatedaswhat`
   - Name: `Reincarnated as WHAT?!`
   - Min SDK 24, arm64-v8a, landscape
   - Adaptive icons from `app_icon/android_adaptive_foreground_432.png` and `android_adaptive_background_432.png`
   - Export format: AAB (`build/android/reincarnated.aab`) for Play
3. For a cable install, switch Export Format to APK and set the path to `build/android/reincarnated.apk`. Debug exports use Godot's debug keystore. Release exports need a keystore filled in on the preset (do not commit the passwords; Godot keeps those in `export_credentials.cfg`, which is gitignored).
4. Install the APK, or upload the AAB to Play Console's internal testing track. Billing and real ads only work on a build Play signed, installed from a testing track, with a license tester account.

## What to create in the consoles

Do these before flipping `USE_TEST_ADS` off.

### AdMob

1. Create an AdMob account and two apps (Android and iOS), or one app per platform. The package name and bundle id must match `com.thongdo.reincarnatedaswhat`.
2. Copy each **App ID** (`ca-app-pub-…~…`) into `REAL_ANDROID_APP_ID` and `REAL_IOS_APP_ID`.
3. Create one **Interstitial** ad unit per platform. Copy the unit ids (`ca-app-pub-…/…`) into `REAL_ANDROID_INTERSTITIAL_UNIT_ID` and `REAL_IOS_INTERSTITIAL_UNIT_ID`.
4. Do not create a banner. Leave the rewarded ids empty until a "pick your form" reward exists. When it does, create a Rewarded unit per platform and paste those ids into the `REAL_*_REWARDED_UNIT_ID` constants. The game calls `Monetization.request_rewarded_form_pick()` and nothing else; that function is not used yet.
5. Privacy & messaging: create a GDPR / EEA message so the UMP form can show in Europe. Do not also create an IDFA message there. The game already shows Apple's tracking prompt after the GDPR form, and a second message would ask twice.
6. Set `USE_TEST_ADS` to `false` and export again. The export step copies the app ids into the binary. Ad unit ids are read when the app runs.

### App Store Connect

1. New app. Name `Reincarnated as WHAT?!`. Bundle id `com.thongdo.reincarnatedaswhat` (register the id under Certificates, Identifiers & Profiles first, with In-App Purchase enabled).
2. In-App Purchases → Non-Consumable. Product id exactly `remove_ads`. Price $2.99. Display name such as "Remove ads". A non-consumable stays owned across reinstalls.
3. The app already has a Restore button on the pause menu and on the card after the first interstitial. Apple requires that.
4. App Privacy labels: see below.
5. Age rating: frequent cartoon violence is already in the game. Ads are interstitials between runs. Answer the ads questions as third-party advertising, unrestricted, not designed for children.

### Google Play Console

1. Create the app. Package name `com.thongdo.reincarnatedaswhat`. Default language whatever you list the store page in. App name `Reincarnated as WHAT?!`.
2. Monetize → Products → In-app products → one-time product. Product id exactly `remove_ads`. Price $2.99. Activate it.
3. Internal testing track, upload the AAB, add your account as a license tester. Play Billing will not complete a purchase on a sideloaded APK.
4. Data safety form: see below.
5. Ads declaration: yes, the app contains ads. Then, after a tester buys remove ads, ads stop.

## When ads show

- Only an interstitial, only after death, and only once the player asks for the next run.
- Not during the first three completed runs. The first chance is between run 3 and run 4, then between 6 and 7, 9 and 10, and so on. That is one ad per three runs.
- Not while a run is being played, and not while a boss fight is still in progress. Dying to a boss ends the fight; the ad, if one is due, waits until the next run is requested.
- No banners. No rewarded ads.
- Buying `remove_ads` turns interstitials off for good. A later refund, once the store query says the product is gone, turns them back on.
- If the ad is not loaded yet, the next run starts anyway.

The pause menu (the form card) has **Remove ads** and **Restore** on a phone build. After the first interstitial that actually plays, the same offer appears before the next run, with **Not now**.

## What the game collects

Three things, and nothing else. No email, phone number, contacts, photos, precise location, or health data.

1. **Ads.** Google AdMob, only on the iOS and Android builds. Google receives the advertising identifier and related device data so it can show and measure the interstitial. If the player taps Ask App Not to Track, iOS does not give AdMob the advertising identifier. Buying `remove_ads` stops the interstitials. The web build does not load AdMob.
2. **Remove ads.** The purchase is handled by Apple (StoreKit) or Google Play. The game keeps a local flag that ads are removed. It does not send the receipt or the payment to our server.
3. **Leaderboard.** The name the player chooses and their scores are stored in Supabase (`scripts/leaderboard.gd`). The same row includes how long the run lasted, which form it was, and a random id the game creates so that device keeps its row. That id is not the advertising identifier. It is stored on the device and sent only with the leaderboard.

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

## What was not run here

Linux CI can export the web build and run the headless smoke test. It cannot compile the Xcode project or the Android Gradle project, and it cannot show a test ad or complete a sandbox purchase. Those steps are the Mac and device passes above.
