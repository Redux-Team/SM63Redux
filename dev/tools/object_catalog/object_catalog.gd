extends Control

const OBJECTS_ROOT: String = "res://game/objects/"
const ICON_SIZE: int = 48
const ORDER_STEP: int = 10
const EXPAND_DELAY_MSEC: int = 500
const WINDOW_FILL: float = 0.85
const HINT: String = "Ctrl+Z undo, Del delete, Ctrl+D duplicate, F2 rename."
const PLACEMENTS: PackedStringArray = [
	"Behind All",
	"Behind Player",
	"Front Player",
	"Front All",
]
const FLAGS: PackedStringArray = [
	"Selectable",
	"Deletable",
	"Layerable",
	"Copyable",
	"Movable",
	"Rotatable",
	"Scalable",
]
const SCENE_TEMPLATE: String = """[gd_scene format=3]

[ext_resource type="Script" path="res://game/object/game_object.gd" id="1"]
[ext_resource type="Texture2D" path="{texture}" id="2"]

[sub_resource type="AtlasTexture" id="IconAtlas"]
atlas = ExtResource("2")
region = {region}

[node name="{node}" type="Node2D"]
script = ExtResource("1")
id = &"{id}"
display_name = "{name}"
category = &"{category}"
group = &"{group}"
flags = 127
icon = SubResource("IconAtlas")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
"""

@export var tree: Tree
@export var search: LineEdit
@export var new_button: Button
@export var duplicate_button: Button
@export var delete_button: Button
@export var reload_button: Button
@export var details: Control
@export var id_label: Label
@export var path_label: Label
@export var icon_preview: TextureRect
@export var name_edit: LineEdit
@export var category_edit: LineEdit
@export var group_edit: LineEdit
@export var order_spin: SpinBox
@export var placement_option: OptionButton
@export var browsable_check: CheckBox
@export var unique_check: CheckBox
@export var flags_container: HFlowContainer
@export var status_label: Label
@export var texture_dialog: FileDialog
@export var delete_dialog: ConfirmationDialog
@export var biome_edit: LineEdit
@export var icon_region_spins: Array[SpinBox]
@export var icon_texture_button: Button
@export var icon_full_button: Button
@export var context_menu: PopupMenu
@export var name_dialog: AcceptDialog
@export var name_dialog_edit: LineEdit

var _selected: Array[ObjectRegistry.Entry] = []
var _flag_checks: Array[CheckBox] = []
var _syncing: bool = false
var _collapsed: Dictionary[String, bool] = {}
var _history: Array[Dictionary] = []
var _batch: Dictionary[String, String] = {}
var _scroll_bar: VScrollBar
var _hover_item: TreeItem
var _hover_since: int = 0
var _texture_for_icon: bool = false
var _menu_header: TreeItem
var _menu_actions: Array[Callable] = []
var _name_callback: Callable


func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_fit_window()
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_MULTI
	tree.allow_rmb_select = true
	tree.columns = 3
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 56)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 180)
	tree.multi_selected.connect(_on_multi_selected.unbind(3))
	tree.item_collapsed.connect(_on_item_collapsed)
	for child: Node in tree.get_children(true):
		if child is VScrollBar:
			_scroll_bar = child
	tree.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	search.text_changed.connect(_rebuild_tree.unbind(1))
	new_button.pressed.connect(_pick_texture.bind(false))
	icon_texture_button.pressed.connect(_pick_texture.bind(true))
	icon_full_button.pressed.connect(_apply_full_icon)
	for spin: SpinBox in icon_region_spins:
		spin.value_changed.connect(_apply_icon_region.unbind(1))
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.empty_clicked.connect(_on_empty_clicked)
	context_menu.id_pressed.connect(_on_menu_pressed)
	name_dialog.confirmed.connect(_on_name_confirmed)
	name_dialog_edit.text_submitted.connect(_on_name_submitted.unbind(1))
	duplicate_button.pressed.connect(_duplicate_selected)
	delete_button.pressed.connect(_confirm_delete)
	reload_button.pressed.connect(_reload)
	texture_dialog.file_selected.connect(_on_texture_selected)
	delete_dialog.confirmed.connect(_delete_selected)
	for i: int in PLACEMENTS.size():
		placement_option.add_item(PLACEMENTS[i], i)
	for i: int in FLAGS.size():
		var check: CheckBox = CheckBox.new()
		check.text = FLAGS[i]
		check.toggled.connect(_on_flag_toggled.bind(i).unbind(1))
		flags_container.add_child(check)
		_flag_checks.append(check)
	
	name_edit.text_submitted.connect(_apply.bind(&"display_name").unbind(1))
	name_edit.focus_exited.connect(_apply.bind(&"display_name"))
	category_edit.text_submitted.connect(_apply.bind(&"category").unbind(1))
	category_edit.focus_exited.connect(_apply.bind(&"category"))
	group_edit.text_submitted.connect(_apply.bind(&"group").unbind(1))
	group_edit.focus_exited.connect(_apply.bind(&"group"))
	biome_edit.text_submitted.connect(_apply.bind(&"biome").unbind(1))
	biome_edit.focus_exited.connect(_apply.bind(&"biome"))
	order_spin.value_changed.connect(_apply.bind(&"order").unbind(1))
	placement_option.item_selected.connect(_apply.bind(&"placement").unbind(1))
	browsable_check.toggled.connect(_apply.bind(&"browsable").unbind(1))
	unique_check.toggled.connect(_apply.bind(&"unique").unbind(1))
	_reload()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_zoom_in"):
		get_window().content_scale_factor += 0.1
	if event.is_action_pressed(&"dev_zoom_out"):
		get_window().content_scale_factor = maxf(get_window().content_scale_factor - 0.1, 0.5)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	
	var handled: bool = true
	match key.get_keycode_with_modifiers():
		KEY_MASK_CTRL | KEY_Z:
			_undo()
		KEY_MASK_CTRL | KEY_F:
			search.grab_focus()
		KEY_MASK_CTRL | KEY_D:
			if _selected.size() == 1:
				_duplicate_selected()
		KEY_DELETE:
			if not _selected.is_empty():
				_confirm_delete()
		KEY_F2:
			var header: TreeItem = tree.get_selected()
			if header and not (header.get_metadata(0) as Dictionary).has("entry"):
				_rename_header(header)
			elif _selected.size() == 1:
				name_edit.grab_focus()
				name_edit.select_all()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _get_drag_data(at: Vector2) -> Variant:
	var item: TreeItem = tree.get_item_at_position(at)
	if item == null:
		return null
	
	var dragged: Array[ObjectRegistry.Entry] = _entries_under(item)
	if not dragged.all(func(entry: ObjectRegistry.Entry) -> bool: return (_selected.has(entry))):
		tree.deselect_all()
		item.select(0)
		_selected.assign(dragged)
		_sync_details()
	
	var preview: HBoxContainer = HBoxContainer.new()
	var icon: TextureRect = TextureRect.new()
	icon.texture = _icon_of(_selected.front())
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(24, 24)
	var label: Label = Label.new()
	label.text = (
			_selected.front().display_name
			if _selected.size() == 1
			else "%d objects" % _selected.size()
	)
	preview.add_child(icon)
	preview.add_child(label)
	tree.set_drag_preview(preview)
	return { "entries": _selected.duplicate() }


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var target: TreeItem = tree.get_item_at_position(at)
	if not (data is Dictionary and (data as Dictionary).has("entries")) or target == null:
		return false
	
	var is_entry: bool = (target.get_metadata(0) as Dictionary).has("entry")
	tree.drop_mode_flags = Tree.DROP_MODE_INBETWEEN if is_entry else Tree.DROP_MODE_ON_ITEM
	if target != _hover_item:
		_hover_item = target
		_hover_since = Time.get_ticks_msec()
	elif target.collapsed and Time.get_ticks_msec() - _hover_since > EXPAND_DELAY_MSEC:
		target.collapsed = false
	if is_entry:
		var anchor: ObjectRegistry.Entry = \
				ObjectRegistry.get_entry((target.get_metadata(0) as Dictionary)["entry"])
		return not ((data as Dictionary)["entries"] as Array).has(anchor)
	
	return true


func _drop_data(at: Vector2, data: Variant) -> void:
	_hover_item = null
	var target: TreeItem = tree.get_item_at_position(at)
	var moved: Array[ObjectRegistry.Entry] = []
	moved.assign((data as Dictionary)["entries"])
	var meta: Dictionary = target.get_metadata(0)
	if meta.has("entry"):
		var anchor: ObjectRegistry.Entry = ObjectRegistry.get_entry(meta["entry"])
		_move(
				moved,
				anchor.category,
				anchor.group,
				anchor,
				tree.get_drop_section_at_position(at) > 0,
		)
	elif meta.has("group"):
		_move(moved, meta["category"], meta["group"], null, true)
	else:
		_write(moved, &"category", meta.get("category"))
		status_label.text = "Moved %d object(s) to %s" % [
			moved.size(),
			meta.get("category"),
		]


func _fit_window() -> void:
	var window: Window = get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	var window_size: Vector2i = (Vector2(usable.size) * WINDOW_FILL).floor()
	window.content_scale_factor = \
			clampf(DisplayServer.screen_get_scale(window.current_screen), 1.0, 2.0)
	window.size = window_size
	window.position = usable.position + (usable.size - window_size) / 2


func _reload() -> void:
	var ids: Array[StringName] = []
	for entry: ObjectRegistry.Entry in _selected:
		ids.append(entry.id)
	
	ObjectRegistry.scan(true)
	_selected.clear()
	for id: StringName in ids:
		var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(id)
		if entry:
			_selected.append(entry)
	_commit()
	_rebuild_tree()
	_sync_details()
	status_label.text = "%d objects. %s" % [
		ObjectRegistry.get_entries().size(),
		HINT,
	]


func _rebuild_tree() -> void:
	var scroll: float = _scroll_bar.value if _scroll_bar else 0.0
	tree.clear()
	var root: TreeItem = tree.create_item()
	var query: String = search.text.strip_edges().to_lower()
	var entries: Array[ObjectRegistry.Entry] = ObjectRegistry.get_entries()
	entries.sort_custom(_compare)
	var categories: Dictionary[StringName, TreeItem] = {}
	var groups: Dictionary[String, TreeItem] = {}
	for entry: ObjectRegistry.Entry in entries:
		if (
				not query.is_empty()
				and not (
						entry.display_name.to_lower().contains(query)
						or String(entry.id).contains(query)
						or String(entry.group).to_lower().contains(query)
				)
		):
			continue
		
		var category_item: TreeItem = categories.get(entry.category)
		if category_item == null:
			category_item = _make_header(
					root,
					(String(entry.category) if not entry.category.is_empty() else "(no category)"),
					{ "category": entry.category },
			)
			categories[entry.category] = category_item
		var group_key: String = "%s/%s" % [entry.category, entry.group]
		var group_item: TreeItem = groups.get(group_key)
		if group_item == null:
			group_item = _make_header(
					category_item,
					(String(entry.group) if not entry.group.is_empty() else "(no group)"),
					{ "category": entry.category, "group": entry.group },
			)
			groups[group_key] = group_item
		
		var item: TreeItem = tree.create_item(group_item)
		var dim: Color = Color(1.0, 1.0, 1.0, 0.45)
		item.set_text(
				0,
				(
						entry.display_name
						+ ("" if entry.biome.is_empty() else "  - %s" % entry.biome)
						+ ("" if entry.browsable else "  (hidden)")
						+ ("  (unique)" if entry.unique else "")
				),
		)
		item.set_custom_color(0, Color.WHITE if entry.browsable else dim)
		item.set_icon(0, _icon_of(entry))
		item.set_icon_max_width(0, 24)
		item.set_tooltip_text(0, entry.path)
		item.set_text(1, str(entry.order))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_custom_color(1, dim)
		item.set_text(2, String(entry.id))
		item.set_custom_color(2, dim)
		item.set_metadata(0, { "entry": entry.id })
		if _selected.any(
				func(selected: ObjectRegistry.Entry) -> bool:
					return selected.id == entry.id
		):
			item.select(0)
	
	for header: TreeItem in categories.values() + groups.values():
		header.set_text(1, str(_entries_under(header).size()))
		header.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		header.set_custom_color(1, Color(1.0, 1.0, 1.0, 0.45))
		header.collapsed = query.is_empty() and _collapsed.get(_header_key(header), false)
	if _scroll_bar:
		_scroll_bar.set_deferred(&"value", scroll)


func _make_header(parent: TreeItem, text: String, meta: Dictionary) -> TreeItem:
	var item: TreeItem = tree.create_item(parent)
	item.set_text(0, text)
	item.set_custom_color(0, Color("6496ed") if meta.has("group") else Color.WHITE)
	item.set_selectable(1, false)
	item.set_selectable(2, false)
	item.set_metadata(0, meta)
	return item


func _header_key(item: TreeItem) -> String:
	var meta: Dictionary = item.get_metadata(0)
	return (
			"%s/%s" % [meta.get("category"), meta.get("group", "")]
			if meta.has("group")
			else String(meta.get("category"))
	)


func _entries_under(item: TreeItem) -> Array[ObjectRegistry.Entry]:
	var found: Array[ObjectRegistry.Entry] = []
	var meta: Dictionary = item.get_metadata(0)
	if meta.has("entry"):
		found.append(ObjectRegistry.get_entry(meta["entry"]))
	for child: TreeItem in item.get_children():
		found.append_array(_entries_under(child))
	
	return found


func _on_item_collapsed(item: TreeItem) -> void:
	if (
			search.text.strip_edges().is_empty()
			and not (item.get_metadata(0) as Dictionary).has("entry")
	):
		_collapsed[_header_key(item)] = item.collapsed


func _icon_of(entry: ObjectRegistry.Entry) -> Texture2D:
	return entry.get_icon()


func _compare(a: ObjectRegistry.Entry, b: ObjectRegistry.Entry) -> bool:
	if a.category != b.category:
		return String(a.category) < String(b.category)
	if a.group != b.group:
		return String(a.group) < String(b.group)
	if a.order != b.order:
		return a.order < b.order
	return a.display_name < b.display_name


func _on_multi_selected() -> void:
	_selected.clear()
	var item: TreeItem = tree.get_next_selected(null)
	while item:
		for entry: ObjectRegistry.Entry in _entries_under(item):
			if not _selected.has(entry):
				_selected.append(entry)
		item = tree.get_next_selected(item)
	_sync_details()


func _sync_details() -> void:
	_syncing = true
	details.visible = not _selected.is_empty()
	duplicate_button.disabled = _selected.size() != 1
	delete_button.disabled = _selected.is_empty()
	if _selected.is_empty():
		_syncing = false
		return
	
	var first: ObjectRegistry.Entry = _selected.front()
	var single: bool = _selected.size() == 1
	id_label.text = String(first.id) if single else "%d objects" % _selected.size()
	path_label.text = first.path if single else ""
	icon_preview.texture = _icon_of(first) if single else null
	name_edit.text = first.display_name if single else ""
	name_edit.editable = single
	category_edit.text = _shared(
			func(entry: ObjectRegistry.Entry) -> Variant:
				return String(entry.category)
	)
	group_edit.text = _shared(
			func(entry: ObjectRegistry.Entry) -> Variant:
				return String(entry.group)
	)
	biome_edit.text = _shared(
			func(entry: ObjectRegistry.Entry) -> Variant:
				return String(entry.biome)
	)
	var atlas: AtlasTexture = first.get_icon() as AtlasTexture
	var region: Rect2 = atlas.region if atlas else Rect2()
	for i: int in icon_region_spins.size():
		var spin: SpinBox = icon_region_spins[i]
		spin.editable = single and atlas != null
		spin.set_value_no_signal(
				[region.position.x, region.position.y, region.size.x, region.size.y][i]
		)
	icon_full_button.disabled = not single
	order_spin.value = first.order
	order_spin.editable = single
	placement_option.select(first.placement)
	browsable_check.button_pressed = first.browsable
	unique_check.button_pressed = first.unique
	for i: int in _flag_checks.size():
		_flag_checks[i].button_pressed = first.flags & (1 << i) != 0
	_syncing = false


func _shared(read: Callable) -> String:
	var value: Variant = read.call(_selected.front())
	return (
			str(value)
			if _selected.all(
					func(entry: ObjectRegistry.Entry) -> bool: return (read.call(entry) == value)
			)
			else ""
	)


func _apply(key: StringName) -> void:
	if _syncing or _selected.is_empty():
		return
	
	var value: Variant
	match key:
		&"display_name":
			value = name_edit.text.strip_edges()
		&"category":
			value = StringName(category_edit.text.strip_edges())
		&"group":
			value = StringName(group_edit.text.strip_edges())
		&"biome":
			value = StringName(biome_edit.text.strip_edges())
		&"order":
			value = int(order_spin.value)
		&"placement":
			value = placement_option.selected
		&"browsable":
			value = browsable_check.button_pressed
		&"unique":
			value = unique_check.button_pressed
	
	if (
			(key == &"category" or key == &"group" or key == &"biome")
			and String(value).is_empty()
			and _selected.size() > 1
			and _shared(
					func(entry: ObjectRegistry.Entry) -> Variant: return (String(entry.get(key)))
			).is_empty()
	):
		return
	
	_write(_selected, key, value)


func _on_flag_toggled(index: int) -> void:
	if _syncing or _selected.is_empty():
		return
	
	var bit: int = 1 << index
	var enabled: bool = _flag_checks[index].button_pressed
	for entry: ObjectRegistry.Entry in _selected:
		_write([entry], &"flags", entry.flags | bit if enabled else entry.flags & ~bit, false)
	_reload()


func _write(
		entries: Array[ObjectRegistry.Entry],
		key: StringName,
		value: Variant,
		reload: bool = true,
) -> void:
	var written: int = 0
	for entry: ObjectRegistry.Entry in entries:
		if entry.get(key) == value:
			continue
		
		var file: ObjectSceneFile = ObjectSceneFile.open(entry.path)
		if file:
			_record(entry.path)
			file.set_value(key, value)
			if file.save() == OK:
				written += 1
	
	if written > 0:
		status_label.text = "Updated %s on %d object(s)" % [key, written]
		if reload:
			_reload()


func _move(
		moved: Array[ObjectRegistry.Entry],
		category: StringName,
		group: StringName,
		anchor: ObjectRegistry.Entry,
		after: bool,
) -> void:
	_write(moved, &"category", category, false)
	_write(moved, &"group", group, false)
	var entries: Array[ObjectRegistry.Entry] = ObjectRegistry.get_entries()
	var members: Array[ObjectRegistry.Entry] = entries.filter(
			func(entry: ObjectRegistry.Entry) -> bool: return (
					entry.category == category
					and entry.group == group
					and not moved.any(
							func(other: ObjectRegistry.Entry) -> bool: return (other.id == entry.id)
					)
			)
	)
	members.sort_custom(_compare)
	var at: int = members.size()
	if anchor:
		var index: int = members.find(anchor)
		at = index + (1 if after else 0) if index >= 0 else members.size()
	for i: int in moved.size():
		members.insert(at + i, moved[i])
	for i: int in members.size():
		_write([members[i]], &"order", (i + 1) * ORDER_STEP, false)
	_reload()
	status_label.text = "Moved %d object(s) to %s > %s" % [
		moved.size(),
		category,
		group,
	]


func _duplicate_selected() -> void:
	var source: ObjectRegistry.Entry = _selected.front()
	var id: StringName = _unique_id(source.id)
	var copy: ObjectSceneFile = ObjectSceneFile.open(source.path).duplicate_as(
			source.path.get_base_dir().path_join("%s.tscn" % id),
			id,
			source.display_name + " Copy",
	)
	_record(copy.path)
	copy.save()
	_select_after_reload(id)


func _create_from_texture(texture_path: String) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		status_label.text = "Not a texture: %s" % texture_path
		return
	
	var category: StringName = \
			_selected.front().category if not _selected.is_empty() else &"Decoration"
	var group: StringName = _selected.front().group if not _selected.is_empty() else &"Misc"
	var id: StringName = \
			_unique_id(StringName(texture_path.get_file().get_basename().to_snake_case()))
	var folder: String = OBJECTS_ROOT.path_join(
			String(category).to_snake_case()
	).path_join(String(group).to_snake_case())
	DirAccess.make_dir_recursive_absolute(folder)
	var texture_size: Vector2 = texture.get_size()
	var region: Rect2 = \
			Rect2(((texture_size - Vector2.ONE * ICON_SIZE) * 0.5).round(), Vector2.ONE * ICON_SIZE)
	var text: String = SCENE_TEMPLATE.format({
		"texture": texture_path,
		"region": "Rect2(%d, %d, %d, %d)" % [
			region.position.x,
			region.position.y,
			ICON_SIZE,
			ICON_SIZE,
		],
		"node": String(id).to_pascal_case(),
		"id": id,
		"name": String(id).capitalize(),
		"category": category,
		"group": group,
	})
	_record(folder.path_join("%s.tscn" % id))
	var file: FileAccess = FileAccess.open(folder.path_join("%s.tscn" % id), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_select_after_reload(id)


func _confirm_delete() -> void:
	delete_dialog.dialog_text = "Delete %s? This removes the scene file%s." % [
		(
				_selected.front().display_name
				if _selected.size() == 1
				else "%d objects" % _selected.size()
		),
		"" if _selected.size() == 1 else "s",
	]
	delete_dialog.popup_centered()


func _delete_selected() -> void:
	for entry: ObjectRegistry.Entry in _selected:
		_record(entry.path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.path))
	status_label.text = "Deleted %d object(s)" % _selected.size()
	_selected.clear()
	_reload()


func _select_after_reload(id: StringName) -> void:
	ObjectRegistry.scan(true)
	_selected.assign(
			[ObjectRegistry.get_entry(id)].filter(
					func(entry: Variant) -> bool: return entry != null
			)
	)
	_reload()
	status_label.text = "Created %s" % id


func _unique_id(base: StringName) -> StringName:
	var id: StringName = base
	var n: int = 2
	while ObjectRegistry.get_entry(id) != null:
		id = StringName("%s_%d" % [base, n])
		n += 1
	
	return id


func _record(path: String) -> void:
	if not _batch.has(path):
		_batch[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _commit() -> void:
	if _batch.is_empty():
		return
	
	_history.append(_batch)
	_batch = {}


func _undo() -> void:
	if _history.is_empty():
		status_label.text = "Nothing to undo"
		return
	
	var files: Dictionary = _history.pop_back()
	for path: String in files:
		var text: String = files[path]
		if text.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	
	_batch.clear()
	_reload()
	status_label.text = "Undid change to %d file(s)" % files.size()


func _pick_texture(for_icon: bool) -> void:
	_texture_for_icon = for_icon
	texture_dialog.popup_centered_ratio(0.6)


func _on_texture_selected(texture_path: String) -> void:
	if not _texture_for_icon:
		_create_from_texture(texture_path)
		return
	
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		status_label.text = "Not a texture: %s" % texture_path
		return
	
	var crop: Vector2 = texture.get_size().minf(ICON_SIZE)
	_set_icons(_selected, texture_path, Rect2(((texture.get_size() - crop) * 0.5).round(), crop))


func _apply_icon_region() -> void:
	var atlas: AtlasTexture = \
			_selected.front().get_icon() as AtlasTexture if _selected.size() == 1 else null
	if _syncing or atlas == null or atlas.atlas == null:
		return
	
	var values: Array[float] = []
	for spin: SpinBox in icon_region_spins:
		values.append(spin.value)
	_set_icons(
			_selected,
			atlas.atlas.resource_path,
			Rect2(values[0], values[1], values[2], values[3]),
	)


func _apply_full_icon() -> void:
	var icon: Texture2D = _selected.front().get_icon()
	var texture: Texture2D = (icon as AtlasTexture).atlas if icon is AtlasTexture else icon
	if texture:
		_set_icons(_selected, texture.resource_path, Rect2(Vector2.ZERO, texture.get_size()))


func _set_icons(entries: Array[ObjectRegistry.Entry], texture_path: String, region: Rect2) -> void:
	for entry: ObjectRegistry.Entry in entries:
		var file: ObjectSceneFile = ObjectSceneFile.open(entry.path)
		if file:
			_record(entry.path)
			file.set_icon(texture_path, region)
			file.save()
	_reload()
	status_label.text = "Icon set on %d object(s)" % entries.size()


func _on_item_mouse_selected(_at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_open_menu(tree.get_selected())


func _on_empty_clicked(_at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_open_menu(null)


func _open_menu(item: TreeItem) -> void:
	context_menu.clear()
	_menu_actions.clear()
	var meta: Dictionary = item.get_metadata(0) if item else {}
	_menu_header = item if item and not meta.has("entry") else null
	if _menu_header:
		var is_group: bool = meta.has("group")
		_add_menu_item(
				"Rename %s..." % ("Group" if is_group else "Category"),
				_rename_header.bind(_menu_header),
		)
		if not _selected.is_empty():
			_add_menu_item(
					"Move Selection Here",
					_move_selection_to.bind(meta.get("category"), meta.get("group", &"")),
			)
		if is_group:
			_add_menu_item(
					"Set Biome for Group...",
					_prompt.bind(
							"Biome",
							String(_entries_under(_menu_header).front().biome),
							_set_key.bind(_entries_under(_menu_header), &"biome"),
					),
			)
	if not _selected.is_empty():
		if context_menu.item_count > 0:
			context_menu.add_separator()
		_add_menu_item(
				"New Group from Selection...",
				_prompt.bind(
						"New Group",
						"",
						func(text: String) -> void: _move_selection_to(
								_selected.front().category,
								StringName(text),
						)
				),
		)
		_add_menu_item(
				"New Category from Selection...",
				_prompt.bind(
						"New Category",
						"",
						func(text: String) -> void: _move_selection_to(
								StringName(text),
								_selected.front().group,
						)
				),
		)
		_add_menu_item(
				"Set Biome...",
				_prompt.bind(
						"Biome",
						String(_selected.front().biome),
						_set_key.bind(_selected.duplicate(), &"biome"),
				),
		)
		var targets: PopupMenu = PopupMenu.new()
		targets.name = "MoveTo"
		var pairs: Array[String] = []
		for entry: ObjectRegistry.Entry in ObjectRegistry.get_entries():
			var pair: String = "%s/%s" % [entry.category, entry.group]
			if not pairs.has(pair):
				pairs.append(pair)
		pairs.sort()
		for pair: String in pairs:
			targets.add_item(pair.replace("/", " > "), _menu_actions.size())
			_menu_actions.append(
					_move_selection_to.bind(
							StringName(pair.get_slice("/", 0)),
							StringName(pair.get_slice("/", 1)),
					)
			)
		targets.id_pressed.connect(_on_menu_pressed)
		context_menu.add_child(targets)
		context_menu.add_submenu_node_item("Move To", targets)
		context_menu.add_separator()
		_add_menu_item("Change Icon Texture...", _pick_texture.bind(true))
		if _selected.size() == 1:
			_add_menu_item("Duplicate", _duplicate_selected)
		else:
			_add_menu_item("Duplicate (single object only)", Callable())
			context_menu.set_item_disabled(context_menu.item_count - 1, true)
		_add_menu_item("Delete...", _confirm_delete)
	if context_menu.item_count == 0:
		return
	
	context_menu.position = (
			Vector2i(get_global_mouse_position() * get_window().content_scale_factor)
			+ get_window().position
	)
	context_menu.reset_size()
	context_menu.popup()


func _add_menu_item(text: String, action: Callable) -> void:
	context_menu.add_item(text, _menu_actions.size())
	_menu_actions.append(action)


func _on_menu_pressed(id: int) -> void:
	_menu_actions[id].call()


func _rename_header(header: TreeItem) -> void:
	var meta: Dictionary = header.get_metadata(0)
	var key: StringName = &"group" if meta.has("group") else &"category"
	_prompt(
			"Rename %s" % String(key).capitalize(),
			String(meta.get(String(key))),
			_set_key.bind(_entries_under(header), key),
	)


func _move_selection_to(category: StringName, group: StringName) -> void:
	if String(category).is_empty():
		return
	
	if String(group).is_empty():
		_write(_selected.duplicate(), &"category", category)
		return
	
	_move(_selected.duplicate(), category, group, null, true)


func _set_key(text: String, entries: Array[ObjectRegistry.Entry], key: StringName) -> void:
	_write(entries, key, StringName(text))
	status_label.text = "Set %s to \"%s\" on %d object(s)" % [
		key,
		text,
		entries.size(),
	]


func _prompt(title: String, initial: String, callback: Callable) -> void:
	_name_callback = callback
	name_dialog.title = title
	name_dialog_edit.text = initial
	name_dialog.popup_centered(Vector2i(300, 90))
	name_dialog_edit.grab_focus()
	name_dialog_edit.select_all()


func _on_name_submitted() -> void:
	name_dialog.hide()
	_on_name_confirmed()


func _on_name_confirmed() -> void:
	var text: String = name_dialog_edit.text.strip_edges()
	if _name_callback.is_valid():
		_name_callback.call(text)
	_name_callback = Callable()
