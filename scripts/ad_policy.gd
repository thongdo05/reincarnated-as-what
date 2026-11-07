class_name AdPolicy

## Pure rules for ads. No SDK, no platform.


static func interstitial_due(runs_completed: int, ads_removed: bool, in_run: bool, boss_fight: bool) -> bool:
	if ads_removed or in_run or boss_fight:
		return false
	if runs_completed < StoreConfig.RUNS_BEFORE_ADS:
		return false
	if StoreConfig.RUNS_BETWEEN_ADS <= 0:
		return false
	return runs_completed % StoreConfig.RUNS_BETWEEN_ADS == 0


## The banner exists only on the death card. A live run, and a player who bought
## remove_ads, never see it.
static func banner_visible(death_screen: bool, in_run: bool, ads_removed: bool) -> bool:
	return death_screen and not in_run and not ads_removed


## The form picker opens only after the rewarded ad pays out.
static func rewarded_opens_picker(reward_earned: bool) -> bool:
	return reward_earned


## The rewarded-form row is only on store builds, and only when a rewarded unit
## exists or remove_ads made the picker free. Otherwise the death card closes up.
static func form_pick_offered(stores: bool, choose_free: bool, rewarded_ready: bool) -> bool:
	if not stores:
		return false
	return choose_free or rewarded_ready


## Slime, Goblin, Vending Machine, Cat, Demon Lord. Dragon is earned in a run.
static func form_is_pickable(id: int) -> bool:
	return id != FormCatalog.Id.DRAGON and FormCatalog.IDS.has(id)
