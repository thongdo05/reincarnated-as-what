extends Node

## Mobile ads and the remove_ads purchase. A no-op on the web and in the editor.
##
## Interstitials are loaded after a run ends and shown only when the player
## asks for the next run. Rewarded ads are not used. request_rewarded_form_pick()
## is the hook a later "pick your form" button can await.

signal state_changed

const SAVE_PATH := "user://monetization.cfg"

var runs_completed := 0
var ads_removed := false
var interstitials_shown := 0
var localized_price := ""

var _billing
var _ios_store: Object
var _att: Object
var _interstitial: Object
var _interstitial_loading := false
var _show_result := ""
var _purchase_result := ""
var _purchase_open := false
var _booted := false


func _ready() -> void:
	_load()
	if not StoreConfig.stores_available():
		return
	call_deferred("_boot")


func store_buttons_visible() -> bool:
	return StoreConfig.stores_available()


func remove_ads_label() -> String:
	if ads_removed:
		return "ADS REMOVED"
	if localized_price.is_empty():
		return "REMOVE ADS"
	return "REMOVE ADS  " + localized_price


func note_run_ended() -> void:
	if not StoreConfig.stores_available():
		return
	runs_completed += 1
	_save()
	if AdPolicy.interstitial_due(runs_completed, ads_removed, false, false):
		_preload_interstitial()


func play_between_runs(in_run: bool, boss_fight: bool) -> bool:
	if not AdPolicy.interstitial_due(runs_completed, ads_removed, in_run, boss_fight):
		_drop_interstitial()
		return false
	if not StoreConfig.stores_available():
		return false
	var shown := await _present_interstitial()
	if shown:
		interstitials_shown += 1
		_save()
	return shown and interstitials_shown == 1 and not ads_removed


func purchase_remove_ads() -> bool:
	if not StoreConfig.stores_available():
		return false
	if ads_removed:
		return true
	_purchase_open = true
	_purchase_result = ""
	if OS.has_feature("ios"):
		if _ios_store == null:
			return false
		_ios_store.request("purchase", {"productID": StoreConfig.REMOVE_ADS_PRODUCT_ID})
	elif _billing != null and _billing.is_ready():
		var launched: Dictionary = _billing.purchase(StoreConfig.REMOVE_ADS_PRODUCT_ID)
		if int(launched.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			return false
	else:
		return false
	var frames := 0
	while _purchase_result.is_empty() and frames < 60 * 180:
		await get_tree().process_frame
		frames += 1
	_purchase_open = false
	return ads_removed


func restore_purchases() -> void:
	if not StoreConfig.stores_available():
		return
	if OS.has_feature("ios"):
		if _ios_store != null:
			_ios_store.request("appStoreSync", {})
		return
	if _billing != null and _billing.is_ready():
		_billing.query_purchases(BillingClient.ProductType.INAPP)


## Later hook. Returns true only when a rewarded ad actually pays out.
## Nothing in the game calls this yet.
func request_rewarded_form_pick() -> bool:
	if not StoreConfig.stores_available():
		return false
	var unit := StoreConfig.rewarded_unit_id()
	if unit.is_empty() or not ClassDB.class_exists("RewardedAdLoader"):
		return false
	var earned := {"ok": false, "done": false}
	var loader: Object = RewardedAdLoader.new()
	var callback: Object = RewardedAdLoadCallback.new()
	callback.on_ad_failed_to_load = func(_error) -> void:
		earned.done = true
	callback.on_ad_loaded = func(ad) -> void:
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
			earned.done = true
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error) -> void:
			earned.done = true
		var listener: Object = OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item) -> void:
			earned.ok = true
		ad.show(listener)
	loader.load(unit, AdRequest.new(), callback)
	var frames := 0
	while not bool(earned.done) and frames < 60 * 120:
		await get_tree().process_frame
		frames += 1
	return bool(earned.ok)


func _boot() -> void:
	if _booted:
		return
	_booted = true
	await _request_consent()
	await _request_tracking()
	_init_ads()
	_init_billing()


func _request_consent() -> void:
	if not ClassDB.class_exists("ConsentInformation"):
		return
	var info: Object = UserMessagingPlatform.consent_information
	var done := {"ok": false}
	info.update(
		ConsentRequestParameters.new(),
		func() -> void: done.ok = true,
		func(_error) -> void: done.ok = true
	)
	var frames := 0
	while not bool(done.ok) and frames < 180:
		await get_tree().process_frame
		frames += 1
	if not bool(done.ok):
		return
	if int(info.get_consent_status()) != int(ConsentInformation.ConsentStatus.REQUIRED):
		return
	var form_done := {"ok": false}
	UserMessagingPlatform.load_consent_form(
		func(form) -> void:
			form.show(func(_error) -> void: form_done.ok = true),
		func(_error) -> void: form_done.ok = true
	)
	frames = 0
	while not bool(form_done.ok) and frames < 60 * 30:
		await get_tree().process_frame
		frames += 1


func _request_tracking() -> void:
	if not OS.has_feature("ios") or not ClassDB.class_exists("GodotIosAtt"):
		return
	_att = ClassDB.instantiate("GodotIosAtt")
	# 0 is NOT_DETERMINED. Later launches return the saved choice and show nothing.
	if int(_att.authorization_status()) != 0:
		return
	var done := {"ok": false}
	_att.tracking_authorization_resolved.connect(func(_status, _authorized) -> void: done.ok = true)
	_att.request_tracking_authorization()
	var frames := 0
	while not bool(done.ok) and frames < 60 * 30:
		await get_tree().process_frame
		frames += 1


func _init_ads() -> void:
	if not ClassDB.class_exists("MobileAds"):
		return
	MobileAds.initialize()


func _init_billing() -> void:
	if OS.has_feature("android") and ClassDB.class_exists("BillingClient"):
		_billing = BillingClient.new()
		_billing.name = "BillingClient"
		add_child(_billing)
		_billing.connected.connect(_on_billing_connected)
		_billing.query_product_details_response.connect(_on_product_details)
		_billing.query_purchases_response.connect(_on_purchases)
		_billing.on_purchase_updated.connect(_on_purchase_updated)
		_billing.acknowledge_purchase_response.connect(_on_acknowledged)
		_billing.start_connection()
		return
	if OS.has_feature("ios") and Engine.has_singleton("IOSInAppPurchase"):
		_ios_store = Engine.get_singleton("IOSInAppPurchase")
		_ios_store.response.connect(_on_ios_store)
		_ios_store.request("startUpdateTask", {})
		_ios_store.request("products", {"productIDs": [StoreConfig.REMOVE_ADS_PRODUCT_ID]})
		_ios_store.request("transactionCurrentEntitlements", {})


func _on_billing_connected() -> void:
	if _billing == null:
		return
	_billing.query_product_details(
		PackedStringArray([StoreConfig.REMOVE_ADS_PRODUCT_ID]),
		BillingClient.ProductType.INAPP
	)
	_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	var price := _find_price(response.get("product_details", []))
	if price.is_empty() or price == localized_price:
		return
	localized_price = price
	state_changed.emit()


func _on_purchases(response: Dictionary) -> void:
	var ok := int(response.get("response_code", -1)) == BillingClient.BillingResponseCode.OK
	if not ok:
		_purchase_result = "error"
		return
	var owned := false
	for purchase in response.get("purchases", []):
		if _android_purchase_is_remove_ads(purchase):
			owned = true
			_acknowledge_if_needed(purchase)
	_set_removed(owned, true)
	if _purchase_open:
		_purchase_result = "owned" if owned else "none"


func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		if _billing != null:
			_billing.query_purchases(BillingClient.ProductType.INAPP)
		return
	if code != BillingClient.BillingResponseCode.OK:
		if _purchase_open:
			_purchase_result = "canceled"
		return
	var owned := false
	for purchase in response.get("purchases", []):
		if _android_purchase_is_remove_ads(purchase):
			owned = true
			_acknowledge_if_needed(purchase)
	if owned:
		_set_removed(true, true)
	if _purchase_open:
		_purchase_result = "owned" if owned else "none"


func _on_acknowledged(_response: Dictionary) -> void:
	pass


func _android_purchase_is_remove_ads(purchase: Dictionary) -> bool:
	if int(purchase.get("purchase_state", -1)) != BillingClient.PurchaseState.PURCHASED:
		return false
	var ids: Variant = purchase.get("product_ids", [])
	for product_id in ids:
		if str(product_id) == StoreConfig.REMOVE_ADS_PRODUCT_ID:
			return true
	return false


func _acknowledge_if_needed(purchase: Dictionary) -> void:
	if bool(purchase.get("is_acknowledged", false)) or _billing == null:
		return
	var token := str(purchase.get("purchase_token", ""))
	if not token.is_empty():
		_billing.acknowledge_purchase(token)


func _on_ios_store(response_name: String, data: Dictionary) -> void:
	var result := str(data.get("result", ""))
	if response_name == "products" and result == "success":
		for product in data.get("products", []):
			if str(product.get("id", "")) != StoreConfig.REMOVE_ADS_PRODUCT_ID:
				continue
			var price := str(product.get("displayPrice", ""))
			if not price.is_empty() and price != localized_price:
				localized_price = price
				state_changed.emit()
		return
	if response_name == "transactionCurrentEntitlements":
		if result != "success":
			return
		var owned := false
		for transaction in data.get("transactions", []):
			if str(transaction.get("productID", "")) != StoreConfig.REMOVE_ADS_PRODUCT_ID:
				continue
			if not str(transaction.get("revocationDate", "")).is_empty():
				continue
			owned = true
		_set_removed(owned, true)
		if _purchase_open and _purchase_result.is_empty():
			_purchase_result = "owned" if owned else "none"
		return
	if response_name == "purchase":
		if result == "success" and str(data.get("productID", "")) == StoreConfig.REMOVE_ADS_PRODUCT_ID:
			if str(data.get("revocationDate", "")).is_empty():
				_set_removed(true, true)
		if _purchase_open:
			_purchase_result = "done"
		return
	if response_name == "appStoreSync" and _ios_store != null:
		_ios_store.request("transactionCurrentEntitlements", {})


func _preload_interstitial() -> void:
	if _interstitial != null or _interstitial_loading or ads_removed:
		return
	var unit := StoreConfig.interstitial_unit_id()
	if unit.is_empty() or not ClassDB.class_exists("InterstitialAdLoader"):
		return
	_interstitial_loading = true
	var loader: Object = InterstitialAdLoader.new()
	var callback: Object = InterstitialAdLoadCallback.new()
	callback.on_ad_failed_to_load = func(_error) -> void:
		_interstitial_loading = false
	callback.on_ad_loaded = func(ad) -> void:
		_interstitial_loading = false
		_interstitial = ad
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
			_show_result = "shown"
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error) -> void:
			_show_result = "failed"
	loader.load(unit, AdRequest.new(), callback)


func _present_interstitial() -> bool:
	var frames := 0
	while _interstitial == null and _interstitial_loading and frames < 90:
		await get_tree().process_frame
		frames += 1
	if _interstitial == null:
		return false
	_show_result = ""
	_interstitial.show()
	frames = 0
	while _show_result.is_empty() and frames < 60 * 120:
		await get_tree().process_frame
		frames += 1
	var shown := _show_result == "shown"
	_drop_interstitial()
	return shown


func _drop_interstitial() -> void:
	if _interstitial != null and _interstitial.has_method("destroy"):
		_interstitial.destroy()
	_interstitial = null
	_interstitial_loading = false


func _set_removed(owned: bool, query_ok: bool) -> void:
	if not query_ok or owned == ads_removed:
		return
	ads_removed = owned
	if owned:
		_drop_interstitial()
	_save()
	state_changed.emit()


func _find_price(details: Variant) -> String:
	if not (details is Array):
		return ""
	for item in details:
		if not (item is Dictionary):
			continue
		if str(item.get("product_id", "")) != StoreConfig.REMOVE_ADS_PRODUCT_ID:
			continue
		var direct := str(item.get("formatted_price", ""))
		if not direct.is_empty():
			return direct
		var offer: Variant = item.get("one_time_purchase_offer_details", {})
		if offer is Dictionary and not str(offer.get("formatted_price", "")).is_empty():
			return str(offer.get("formatted_price", ""))
		for option in item.get("purchase_options", []):
			if not (option is Dictionary):
				continue
			var nested := str(option.get("formatted_price", ""))
			if not nested.is_empty():
				return nested
			var phase: Variant = option.get("offer", {})
			if phase is Dictionary and not str(phase.get("formatted_price", "")).is_empty():
				return str(phase.get("formatted_price", ""))
	return ""


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	runs_completed = int(file.get_value("store", "runs_completed", 0))
	ads_removed = bool(file.get_value("store", "ads_removed", false))
	interstitials_shown = int(file.get_value("store", "interstitials_shown", 0))


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("store", "runs_completed", runs_completed)
	file.set_value("store", "ads_removed", ads_removed)
	file.set_value("store", "interstitials_shown", interstitials_shown)
	file.save(SAVE_PATH)
