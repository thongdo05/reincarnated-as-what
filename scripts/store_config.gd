class_name StoreConfig

## The only place real store and ad IDs go.
##
## USE_TEST_ADS stays true for dev and for a TestFlight run that leaves the
## workflow box unchecked. Those builds request Google's sample ad units.
## The iOS TestFlight workflow flips this to false only when use_real_ads is
## checked. That edit stays on the runner. A real-ads build serves the
## interstitial and rewarded units below. Banner real units stay empty, so
## that build does not request a banner. The app ids are always the real ones:
## export writes them into Info.plist and the Android manifest either way.
##
## A CrazyGames export (feature "crazygames") never offers AdMob, the
## remove_ads purchase, or the pause-screen privacy and support links. Those
## stay on the iOS and Android builds. The web Pages build already has no
## store, because stores_available() is false for every web export.
##
## App IDs contain "~". Ad unit IDs contain "/".
## The price of remove_ads is set in the stores, not in code.

const USE_TEST_ADS := true

const REAL_ANDROID_APP_ID := "ca-app-pub-1397621797560860~1097269219"
const REAL_IOS_APP_ID := "ca-app-pub-1397621797560860~9031599553"
const REAL_ANDROID_BANNER_UNIT_ID := ""
const REAL_IOS_BANNER_UNIT_ID := ""
const REAL_ANDROID_INTERSTITIAL_UNIT_ID := "ca-app-pub-1397621797560860/3747483284"
const REAL_IOS_INTERSTITIAL_UNIT_ID := "ca-app-pub-1397621797560860/3293196875"
const REAL_ANDROID_REWARDED_UNIT_ID := "ca-app-pub-1397621797560860/6919908709"
const REAL_IOS_REWARDED_UNIT_ID := "ca-app-pub-1397621797560860/3491799585"

const REMOVE_ADS_PRODUCT_ID := "remove_ads"

## Challenge and share links. One constant per platform. All three point at the
## browser game until the app is on the App Store: a friend can play that link
## right away. TODO: Once the App Store listing exists, mobile should use a
## link that sends phone users to the App Store and everyone else to the web game.
const WEB_GAME_URL := "https://thongdo05.github.io/reincarnated-as-what/"
const IOS_GAME_URL := "https://thongdo05.github.io/reincarnated-as-what/"
const ANDROID_GAME_URL := "https://thongdo05.github.io/reincarnated-as-what/"

## Opened from the pause screen on iOS and Android. The Pages site hosts both.
const PRIVACY_URL := "https://thongdo05.github.io/reincarnated-as-what/privacy.html"
const SUPPORT_URL := "https://thongdo05.github.io/reincarnated-as-what/support.html"

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
	return banner_unit_for(USE_TEST_ADS, OS.has_feature("ios"))


static func interstitial_unit_id() -> String:
	if not stores_available():
		return ""
	return interstitial_unit_for(USE_TEST_ADS, OS.has_feature("ios"))


static func rewarded_unit_id() -> String:
	if not stores_available():
		return ""
	return rewarded_unit_for(USE_TEST_ADS, OS.has_feature("ios"))


## Pure lookups so a headless check can see which unit a build would request.
## An empty banner id means that build does not load a banner.
static func banner_unit_for(test_ads: bool, ios: bool) -> String:
	return _platform_unit(
		test_ads,
		ios,
		TEST_IOS_BANNER_UNIT_ID,
		TEST_ANDROID_BANNER_UNIT_ID,
		REAL_IOS_BANNER_UNIT_ID,
		REAL_ANDROID_BANNER_UNIT_ID
	)


static func interstitial_unit_for(test_ads: bool, ios: bool) -> String:
	return _platform_unit(
		test_ads,
		ios,
		TEST_IOS_INTERSTITIAL_UNIT_ID,
		TEST_ANDROID_INTERSTITIAL_UNIT_ID,
		REAL_IOS_INTERSTITIAL_UNIT_ID,
		REAL_ANDROID_INTERSTITIAL_UNIT_ID
	)


static func rewarded_unit_for(test_ads: bool, ios: bool) -> String:
	return _platform_unit(
		test_ads,
		ios,
		TEST_IOS_REWARDED_UNIT_ID,
		TEST_ANDROID_REWARDED_UNIT_ID,
		REAL_IOS_REWARDED_UNIT_ID,
		REAL_ANDROID_REWARDED_UNIT_ID
	)


static func _platform_unit(
	test_ads: bool,
	ios: bool,
	test_ios: String,
	test_android: String,
	real_ios: String,
	real_android: String
) -> String:
	if test_ads:
		return test_ios if ios else test_android
	var real := real_ios if ios else real_android
	return real.strip_edges()


static func game_url() -> String:
	return game_url_for(OS.has_feature("ios"), OS.has_feature("android"))


static func game_url_for(ios: bool, android: bool) -> String:
	if ios:
		return IOS_GAME_URL
	if android:
		return ANDROID_GAME_URL
	return WEB_GAME_URL


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
