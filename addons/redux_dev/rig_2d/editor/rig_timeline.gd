@tool
class_name RigTimeline
extends VBoxContainer


enum ClipAction {
	NEW,
	RENAME,
	DUPLICATE,
	DELETE,
	MOVE_UP,
	MOVE_DOWN,
	STORE_RESET,
	CLEAR_RESET,
}

const KEY_SCOPES: PackedStringArray = ["Frame", "Clip", "All"]
const KEY_SCOPE_TIPS: PackedStringArray = [
	"Auto key: moving an anchor in the 2D viewport keys the current frame.",
	"Auto key: moving an anchor in the 2D viewport offsets every frame of this clip.",
	"Auto key: moving an anchor in the 2D viewport offsets every frame of every clip.",
]

@export var edits: RigEdits
@export var previous: Button
@export var next: Button
@export var clips: OptionButton
@export var clip_menu: MenuButton
@export var fps: SpinBox
@export var loop: Button
@export var play: Button
@export var reset: Button
@export var preview: MenuButton
@export var add_menu: MenuButton
@export var auto_key: Button
@export var key_scope: MenuButton
@export var grid: RigTimelineGrid
@export var rename_dialog: ConfirmationDialog
@export var rename_field: LineEdit
@export var variant_dialog: ConfirmationDialog
@export var variant_axis: LineEdit
@export var variant_value: LineEdit

var rig: SpriteRig2D

var _dirty: bool = false
var _stamp: Array = []
var _axes_signature: String = ""
var _clip_signature: String = ""
var _editing_variant: RigVariant


func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	clip_menu.get_popup().id_pressed.connect(_on_clip_action)
	preview.get_popup().index_pressed.connect(_on_preview_index_pressed)
	preview.get_popup().hide_on_checkable_item_selection = false
	add_menu.get_popup().id_pressed.connect(func(id: int) -> void: edits.add_node(id == 1))
	add_menu.get_popup().set_item_icon(0, _icon(&"Sprite2D"))
	add_menu.get_popup().set_item_icon(1, _icon(&"Marker2D"))
	rename_dialog.register_text_enter(rename_field)
	variant_dialog.register_text_enter(variant_value)
	key_scope.get_popup().id_pressed.connect(_on_key_scope_selected)
	edits.undo_redo.version_changed.connect(func() -> void: _dirty = true)
	_apply_icons(self)
	set_rig(null)


func _process(_delta: float) -> void:
	if not is_instance_valid(rig):
		set_rig(null)
		return
	
	rig.refresh()
	var stamp: Array = [
		rig.current_animation,
		rig.current_frame,
		rig.playing,
		RigAnchor.auto_key,
		RigAnchor.key_scope,
	]
	if _dirty or stamp != _stamp:
		_dirty = false
		_stamp = stamp
		_sync()


func set_rig(new_rig: SpriteRig2D) -> void:
	if new_rig == rig and new_rig != null:
		return
	
	rig = new_rig
	edits.rig = rig
	grid.rig = rig
	_dirty = true
	_axes_signature = ""
	_clip_signature = ""
	set_process(rig != null)


func _apply_icons(node: Node) -> void:
	for child: Node in node.get_children():
		if child.has_meta(&"editor_icon"):
			var icon: Texture2D = _icon(child.get_meta(&"editor_icon"))
			if child is Button:
				(child as Button).icon = icon
			elif child is TextureRect:
				(child as TextureRect).texture = icon
		_apply_icons(child)


func _icon(icon: StringName) -> Texture2D:
	return get_theme_icon(icon, &"EditorIcons")


func _sync() -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation)
	play.set_pressed_no_signal(rig.playing)
	play.icon = _icon(&"Pause" if rig.playing else &"Play")
	fps.editable = clip != null
	loop.disabled = clip == null
	if clip:
		fps.set_value_no_signal(clip.fps)
		loop.set_pressed_no_signal(clip.loop)
	_sync_auto_key()
	_sync_reset()
	_sync_clips()
	_sync_variants()
	grid.refresh()


func _sync_auto_key() -> void:
	var popup: PopupMenu = key_scope.get_popup()
	for i: int in popup.item_count:
		popup.set_item_checked(i, i == RigAnchor.key_scope)
	key_scope.text = KEY_SCOPES[RigAnchor.key_scope]
	auto_key.set_pressed_no_signal(RigAnchor.auto_key)
	auto_key.tooltip_text = KEY_SCOPE_TIPS[RigAnchor.key_scope]


func _sync_reset() -> void:
	reset.disabled = not rig.has_reset()
	clip_menu.get_popup().set_item_disabled(
			clip_menu.get_popup().get_item_index(ClipAction.CLEAR_RESET),
			not rig.has_reset(),
	)
	if not rig.has_reset():
		reset.tooltip_text = "No reset state stored. Use the clip menu to store the current one."
		return
	
	var active: PackedStringArray = []
	for axis: StringName in rig.reset_variants:
		if not rig.reset_variants[axis].is_empty():
			active.append("%s: %s" % [axis, rig.reset_variants[axis]])
	reset.tooltip_text = "Reset to %s, frame %d%s.\nScenes open and save in this state." % [
		rig.reset_animation,
		rig.reset_frame + 1,
		"" if active.is_empty() else " (%s)" % ", ".join(active),
	]


func _sync_clips() -> void:
	var names: PackedStringArray = rig.get_clip_names()
	var signature: String = ",".join(names) + "|" + rig.reset_animation
	if signature != _clip_signature:
		_clip_signature = signature
		clips.clear()
		for clip: String in names:
			clips.add_item(clip)
			if clip == rig.reset_animation:
				clips.set_item_icon(clips.item_count - 1, _icon(&"Reload"))
		if names.is_empty():
			clips.add_item("No clips")
			clips.set_item_disabled(0, true)
	var index: int = names.find(rig.current_animation)
	if clips.selected != index and not names.is_empty():
		clips.select(index)


func _sync_variants() -> void:
	var axes: Dictionary[StringName, PackedStringArray] = _collect_axes()
	var popup: PopupMenu = preview.get_popup()
	var signature: String = str(axes)
	if signature != _axes_signature:
		_axes_signature = signature
		popup.clear()
		for axis: StringName in axes:
			popup.add_separator(String(axis).capitalize())
			for value: String in axes[axis]:
				popup.add_radio_check_item("None" if value.is_empty() else value)
				popup.set_item_metadata(popup.item_count - 1, [axis, value])
		if axes.is_empty():
			popup.add_item("This rig has no variants")
			popup.set_item_disabled(0, true)
	var active: int = 0
	for i: int in popup.item_count:
		var pair: Array = popup.get_item_metadata(i) if popup.get_item_metadata(i) else []
		if pair.is_empty():
			continue
		var checked: bool = rig.get_variant(pair[0]) == pair[1]
		popup.set_item_checked(i, checked)
		if checked and not pair[1].is_empty():
			active += 1
	preview.text = "" if active == 0 else str(active)


func _collect_axes() -> Dictionary[StringName, PackedStringArray]:
	var axes: Dictionary[StringName, PackedStringArray] = {}
	for layer: RigLayer in rig.get_layers():
		for axis: StringName in layer.visible_when:
			var wanted: StringName = layer.visible_when[axis]
			_add_value(axes, axis, "on" if wanted.is_empty() else String(wanted))
		for variant: RigVariant in layer.variants:
			if variant:
				_add_value(axes, variant.axis, variant.value)
	for axis: StringName in rig.variants:
		if not rig.variants[axis].is_empty():
			_add_value(axes, axis, rig.variants[axis])
	return axes


func _add_value(
		axes: Dictionary[StringName, PackedStringArray],
		axis: StringName,
		value: String,
) -> void:
	var values: PackedStringArray = axes.get(axis, PackedStringArray([""]))
	if not values.has(value):
		values.append(value)
	axes[axis] = values


func _on_clip_action(id: int) -> void:
	match id:
		ClipAction.NEW:
			edits.add_clip()
			_open_rename()
		ClipAction.RENAME:
			_open_rename()
		ClipAction.DUPLICATE:
			edits.duplicate_clip()
		ClipAction.DELETE:
			edits.delete_clip()
		ClipAction.MOVE_UP, ClipAction.MOVE_DOWN:
			edits.move_clip(-1 if id == ClipAction.MOVE_UP else 1)
		ClipAction.STORE_RESET, ClipAction.CLEAR_RESET:
			edits.store_reset(id == ClipAction.STORE_RESET)


func _open_rename() -> void:
	if rig.get_clip(rig.current_animation) == null:
		return
	
	rename_field.text = rig.current_animation
	rename_dialog.popup_centered()
	rename_field.select_all()
	rename_field.grab_focus()


func _on_rename_confirmed() -> void:
	edits.rename_clip(StringName(rename_field.text.strip_edges()))


func _open_variant_dialog(variant: RigVariant) -> void:
	_editing_variant = variant
	variant_axis.text = variant.axis
	variant_value.text = variant.value
	variant_dialog.popup_centered()
	variant_axis.grab_focus()


func _on_variant_confirmed() -> void:
	var axis: StringName = StringName(variant_axis.text.strip_edges())
	var value: StringName = StringName(variant_value.text.strip_edges())
	if _editing_variant and not axis.is_empty():
		edits.edit_variant(_editing_variant, axis, value)


func _step(direction: int) -> void:
	var length: int = rig.get_clip_length(rig.current_animation)
	rig.playing = false
	rig.current_frame = posmod(rig.current_frame + direction, length)


func _key(add: bool) -> void:
	var anchor: RigAnchor = grid.get_selected_anchor()
	if anchor == null:
		return
	
	if add:
		edits.key(anchor, rig.current_frame)
	else:
		edits.clear_key(anchor, rig.current_frame)


func _on_clip_selected(index: int) -> void:
	rig.playing = false
	rig.current_animation = StringName(clips.get_item_text(index))
	rig.current_frame = 0


func _on_fps_changed(value: float) -> void:
	edits.set_clip_property(&"fps", value)


func _on_loop_toggled(on: bool) -> void:
	edits.set_clip_property(&"loop", on)


func _on_play_toggled(on: bool) -> void:
	if on and rig.current_frame >= rig.get_clip_length(rig.current_animation) - 1:
		rig.current_frame = 0
	rig.playing = on


func _on_reset_pressed() -> void:
	edits.reset()


func _on_preview_index_pressed(index: int) -> void:
	var pair: Array = preview.get_popup().get_item_metadata(index)
	edits.set_variant(pair[0], StringName(pair[1]))


func _on_auto_key_toggled(on: bool) -> void:
	RigAnchor.auto_key = on


func _on_key_scope_selected(id: int) -> void:
	RigAnchor.key_scope = id as RigAnchor.KeyScope
	RigAnchor.auto_key = true


func _on_grid_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	
	for button: Button in [previous, next]:
		if button.shortcut.matches_event(event):
			button.pressed.emit()
			accept_event()
