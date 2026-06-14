class_name LDUIHotbarHandler
extends Node

## Owns the object hotbar buttons. When a hotbar slot asks for a new object it opens the
## object browser, then assigns whatever the user picks back to that slot. Reached via
## LD.get_ui().get_hotbar_handler().

@export var _hotbar_buttons: Array[LDHotbarButton]


var _pending_button: LDHotbarButton = null


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	for button: LDHotbarButton in _hotbar_buttons:
		button.new_object_request.connect(_on_new_object_request)

	var browser: LDObjectBrowser = LD.get_ui().get_window_handler().get_object_browser()
	if browser:
		browser.hide_request.connect(_on_browser_hide_request)


func _on_new_object_request(button: LDHotbarButton) -> void:
	_pending_button = button
	LD.get_ui().get_window_handler().open(LDUIWindowHandler.OBJECT_BROWSER)


func _on_browser_hide_request() -> void:
	LD.get_ui().get_window_handler().close()

	if not _pending_button:
		return
	var button: LDHotbarButton = _pending_button
	_pending_button = null

	# A stamp pick arms a stamp; an object pick clears it. Check the stamp first.
	var stamp: LDStamp = LD.get_stamp_handler().get_armed_stamp()
	if stamp:
		button.assign_stamp(stamp.id)
		return

	var selected: GameObject = LD.get_object_handler().get_selected_object()
	if selected:
		button.assign_object(selected)
