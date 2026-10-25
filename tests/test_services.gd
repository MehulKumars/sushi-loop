extends GutTest
## Service contract: results arrive after the call returns, never inside it, so screens can call
## and then await (a phone test found the shop waiting forever on a mock that answered at once).



func test_mock_purchase_answers_after_the_call() -> void:
	var iap := MockIAPService.new()
	add_child_autofree(iap)
	watch_signals(iap)
	iap.purchase("coins_1")
	assert_signal_not_emitted(iap, "purchase_finished", "must not answer inside purchase()")
	var result: Array = await iap.purchase_finished
	assert_eq(result, ["coins_1", true])
	assert_true(iap.is_owned("coins_1"))
	# Let the emit finish before the test frees the node.
	await wait_process_frames(1)


func test_mock_rewarded_ad_answers_after_the_call() -> void:
	var ads := MockAdsService.new()
	add_child_autofree(ads)
	watch_signals(ads)
	ads.show_rewarded("continue")
	assert_signal_not_emitted(ads, "rewarded_finished")
	var result: Array = await ads.rewarded_finished
	assert_eq(result[0], "continue")
	await wait_process_frames(1)


func test_base_interfaces_answer_after_the_call() -> void:
	var iap := IAPService.new()
	var ads := AdsService.new()
	add_child_autofree(iap)
	add_child_autofree(ads)
	watch_signals(iap)
	watch_signals(ads)
	iap.purchase("x")
	ads.show_rewarded("y")
	ads.show_interstitial("z")
	assert_signal_not_emitted(iap, "purchase_finished")
	assert_signal_not_emitted(ads, "rewarded_finished")
	assert_signal_not_emitted(ads, "interstitial_closed")
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(iap, "purchase_finished", ["x", false])
	assert_signal_emitted(ads, "rewarded_finished")
	assert_signal_emitted(ads, "interstitial_closed")
