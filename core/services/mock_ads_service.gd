class_name MockAdsService
extends AdsService
## Fake ads for the editor and PC: waits briefly, then reports the result.
## Toggle grant_rewards from the dev console with `ads_grant false` to test the "no reward" path.
## In a release build the mock reports no ads ready and never grants rewards, so a game shipped
## before real ads are wired cannot hand out free rewards. Test builds for phones that carry the
## `test_ads` export feature (only the sideloaded APK preset; never the Play preset) keep the
## fake ads, so the video offers can be tried on a phone with a release-speed build.

var simulated_delay_sec: float = 0.5
var grant_rewards: bool = _fake_ads_on()


func is_rewarded_ready(_placement: String) -> bool:
	return _fake_ads_on()


func show_rewarded(placement: String) -> void:
	print("[MockAds] rewarded '%s'" % placement)
	await get_tree().create_timer(simulated_delay_sec, true, false, true).timeout
	rewarded_finished.emit(placement, grant_rewards)


func is_interstitial_ready(_placement: String) -> bool:
	return _fake_ads_on()


func show_interstitial(placement: String) -> void:
	print("[MockAds] interstitial '%s'" % placement)
	await get_tree().create_timer(simulated_delay_sec, true, false, true).timeout
	interstitial_closed.emit(placement)


static func _fake_ads_on() -> bool:
	return OS.is_debug_build() or OS.has_feature("test_ads")
