class_name StoreConfig

## The only place real store and ad IDs go.
##
## USE_TEST_ADS stays true for dev and TestFlight. Those builds request Google's
## sample ad units. Set it to false only for a store build that should serve
## the real interstitial units below. The app ids are always the real ones:
## export writes them into Info.plist and the Android manifest either way.
##
## A CrazyGames export (feature "crazygames") never offers AdMob, the
## remove_ads purchase, or a link to the App Store or Google Play. Those
## stay on the iOS and Android builds. The web Pages build already has no
## store, because stores_available() is false for every web export.
##
## App IDs contain "~". Ad unit IDs contain "/".
## Banner and rewarded real units are still empty.
## The price of remove_ads is set in the stores, not in code.

const USE_TEST_ADS := true

const REAL_ANDROID_APP_ID := "ca-app-pub-1397621797560860~1097269219"
const REAL_IOS_APP_ID := "ca-app-pub-1397621797560860~9031599553"
const REAL_ANDROID_BANNER_UNIT_ID := ""
const REAL_IOS_BANNER_UNIT_ID := ""
const REAL_ANDROID_INTERSTITIAL_UNIT_ID := "ca-app-pub-1397621797560860/3747483284"
const REAL_IOS_INTERSTITIAL_UNIT_ID := "ca-app-pub-1397621797560860/3293196875"
const REAL_ANDROID_REWARDED_UNIT_ID := ""
const REAL_IOS_REWARDED_UNIT_ID := ""

const REMOVE_ADS_PRODUCT_ID := "remove_ads"

const TEST_ANDROID_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const TEST_IOS_APP_ID := "ca-app-pub-3940256099942544~1458002511"
const TEST_ANDROID_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"
const TEST_IOS_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/2934735716"
const TEST_ANDROID_INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_IOS_INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/4411468910"
const TEST_ANDROID_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_IOS_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"

## Shown by iOS as the App Tracking Transparency prompt. Plain language, no joke.
const ATT_USAGE_DESCRIPTION := "This lets Reincarnated as WHAT?! show ads that are more relevant to you between runs. The game plays the same if you choose Ask App Not to Track."

## The first five completed runs never get an interstitial. After that, one
## interstitial per five completed runs (after runs 5, 10, 15, ...), and only
## between runs. A boss that is still being fought blocks the ad.
const RUNS_BEFORE_ADS := 5
const RUNS_BETWEEN_ADS := 5


static func crazygames_build() -> bool:
	return OS.has_feature("crazygames") or OS.has_feature("CRAZYGAMES")


## Editor, web, and CrazyGames builds have no store. Android and iOS do,
## unless the export is also tagged as CrazyGames.
static func stores_allowed(crazygames: bool, editor: bool, web: bool, android: bool, ios: bool) -> bool:
	if crazygames or editor or web:
		return false
	return android or ios


static func stores_available() -> bool:
	return stores_allowed(
		crazygames_build(),
		OS.has_feature("editor"),
		OS.has_feature("web"),
		OS.has_feature("android"),
		OS.has_feature("ios")
	)


## Always the real app id. AdMob wants this in the binary even when the
## requests use Google's test ad units.
static func ios_app_id() -> String:
	return REAL_IOS_APP_ID.strip_edges()


static func android_app_id() -> String:
	return REAL_ANDROID_APP_ID.strip_edges()


static func banner_unit_id() -> String:
	if not stores_available():
		return ""
	var ios := OS.has_feature("ios")
	if USE_TEST_ADS:
		return TEST_IOS_BANNER_UNIT_ID if ios else TEST_ANDROID_BANNER_UNIT_ID
	var real := REAL_IOS_BANNER_UNIT_ID if ios else REAL_ANDROID_BANNER_UNIT_ID
	return real.strip_edges()


static func interstitial_unit_id() -> String:
	if not stores_available():
		return ""
	var ios := OS.has_feature("ios")
	if USE_TEST_ADS:
		return TEST_IOS_INTERSTITIAL_UNIT_ID if ios else TEST_ANDROID_INTERSTITIAL_UNIT_ID
	var real := REAL_IOS_INTERSTITIAL_UNIT_ID if ios else REAL_ANDROID_INTERSTITIAL_UNIT_ID
	return real.strip_edges()


static func rewarded_unit_id() -> String:
	if not stores_available():
		return ""
	var ios := OS.has_feature("ios")
	if USE_TEST_ADS:
		return TEST_IOS_REWARDED_UNIT_ID if ios else TEST_ANDROID_REWARDED_UNIT_ID
	var real := REAL_IOS_REWARDED_UNIT_ID if ios else REAL_ANDROID_REWARDED_UNIT_ID
	return real.strip_edges()


static func real_ids_are_empty() -> bool:
	return (
		REAL_ANDROID_APP_ID.strip_edges().is_empty()
		and REAL_IOS_APP_ID.strip_edges().is_empty()
		and REAL_ANDROID_BANNER_UNIT_ID.strip_edges().is_empty()
		and REAL_IOS_BANNER_UNIT_ID.strip_edges().is_empty()
		and REAL_ANDROID_INTERSTITIAL_UNIT_ID.strip_edges().is_empty()
		and REAL_IOS_INTERSTITIAL_UNIT_ID.strip_edges().is_empty()
		and REAL_ANDROID_REWARDED_UNIT_ID.strip_edges().is_empty()
		and REAL_IOS_REWARDED_UNIT_ID.strip_edges().is_empty()
	)


static func att_plist() -> String:
	var text := ATT_USAGE_DESCRIPTION.xml_escape(true)
	return "<key>NSUserTrackingUsageDescription</key><string>%s</string>\n" % text
