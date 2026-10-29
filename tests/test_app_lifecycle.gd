extends GutTest
## AppLifecycle applies the player's motion and haptics choices from Settings,
## and forwards Android lifecycle notifications to Events. Settings use a test file.

const TEST_PATH: String = "user://test_settings.cfg"

var _real_path: String = ""


func before_each() -> void:
	_real_path = Settings.path
	Settings.path = TEST_PATH
	Settings.clear()


func after_each() -> void:
	Settings.clear()
	Settings.path = _real_path
	Settings.load_from_disk()
	AppLifecycle.apply_settings()


func test_defaults_are_full_motion_and_haptics_on() -> void:
	AppLifecycle.apply_settings()
	assert_eq(Juice.motion_scale, 1.0)
	assert_true(Haptics.enabled)


func test_player_choices_are_applied() -> void:
	Settings.set_reduce_motion(true)
	Settings.set_haptics(false)
	assert_eq(Juice.motion_scale, 0.0)
	assert_false(Haptics.enabled)


func test_choices_survive_a_restart() -> void:
	Settings.set_reduce_motion(true)
	Settings.set_volume(Settings.MUSIC_BUS, 0.25)
	Settings.load_from_disk()
	assert_true(Settings.reduce_motion())
	assert_almost_eq(Settings.volume(Settings.MUSIC_BUS), 0.25, 0.001)


func test_volume_reaches_the_audio_bus() -> void:
	Settings.set_volume(Settings.SFX_BUS, 0.5)
	var index := AudioServer.get_bus_index(Settings.SFX_BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01)
	Settings.set_volume(Settings.SFX_BUS, 0.0)
	assert_true(AudioServer.is_bus_mute(index), "zero volume mutes the bus")
	Settings.set_volume(Settings.SFX_BUS, 1.0)


func test_lifecycle_notifications_reach_events() -> void:
	watch_signals(Events)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	AppLifecycle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_signal_emitted(Events, "app_paused")
	assert_signal_emitted(Events, "app_resumed")
	assert_signal_emitted(Events, "back_requested")
