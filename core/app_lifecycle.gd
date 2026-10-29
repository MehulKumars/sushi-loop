extends Node
## App lifecycle and player feel settings (autoload "AppLifecycle").
## Turns Android lifecycle notifications into Events signals, and applies the player's
## motion and haptics choices from Settings (user://settings.cfg). At start it also restores the
## saved music and sound volumes.
##
## Games: save progress on Events.app_paused (Android may kill a paused app without
## warning). Back arrives as the ui_cancel action (see UI); Events.back_requested also fires.
## project.godot sets application/config/quit_on_go_back=false so Back does not quit.
## Settings calls apply_settings() after every change.


func _ready() -> void:
	Settings.apply_audio()
	apply_settings()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			Events.app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			apply_settings()
			Events.app_resumed.emit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			Events.back_requested.emit()


## Reads the player's choices and pushes them into Juice and Haptics.
func apply_settings() -> void:
	Juice.motion_scale = 0.0 if Settings.reduce_motion() else 1.0
	Haptics.enabled = Settings.haptics()
