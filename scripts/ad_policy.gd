class_name AdPolicy

## Pure rules for when an interstitial may appear. No SDK, no platform.


static func interstitial_due(runs_completed: int, ads_removed: bool, in_run: bool, boss_fight: bool) -> bool:
	if ads_removed or in_run or boss_fight:
		return false
	if runs_completed < StoreConfig.RUNS_BEFORE_ADS:
		return false
	if StoreConfig.RUNS_BETWEEN_ADS <= 0:
		return false
	return runs_completed % StoreConfig.RUNS_BETWEEN_ADS == 0
