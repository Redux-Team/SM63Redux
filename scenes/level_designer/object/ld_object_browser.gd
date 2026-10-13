class_name LDObjectBrowser
extends LDPanel

signal picked(entry: ObjectRegistry.Entry)

const CHIP_CLASS: String = "Chip"

@export var search: LineEdit
@export var category_bar: HBoxContainer
@export var groups: VBoxContainer
@export var group_scene: PackedScene
@export var entry_scene: PackedScene
@export var highlight_color: Color = Color("3da4ff")
@export var build_budget_usec: int = 4000

var _category: StringName = &""
var _chips: ButtonGroup = ButtonGroup.new()
var _queue: Array[Array] = []


func _setup() -> void:
	super()
	_chips.pressed.connect(_on_chip_pressed)
	search.text_changed.connect(_populate.unbind(1))
	_build_chips()
	_populate()


func _process(_delta: float) -> void:
	_build(build_budget_usec)


func get_title() -> String:
	return "Objects - %s" % (String(_category) if not _category.is_empty() else "All")


func _on_open() -> void:
	_build(0)


func _build_chips() -> void:
	var categories: Array[StringName] = [&""]
	for entry: ObjectRegistry.Entry in ObjectRegistry.get_entries():
		if entry.browsable and not categories.has(entry.category):
			categories.append(entry.category)
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return a.is_empty() or (not b.is_empty() and String(a) < String(b)))
	
	for category: StringName in categories:
		var chip: Button = Button.new()
		chip.text = String(category) if not category.is_empty() else "All"
		chip.name = chip.text.validate_node_name()
		chip.toggle_mode = true
		chip.button_group = _chips
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.set_meta(&"category", category)
		chip.set_pressed_no_signal(category.is_empty())
		GDSS.add_class(chip, CHIP_CLASS)
		category_bar.add_child(chip)


func _on_chip_pressed(chip: BaseButton) -> void:
	_category = chip.get_meta(&"category")
	SFX.play(SFX.LD_SELECT)
	_populate()
	if is_open():
		editor.interface_handler.window.set_title(get_title())


func _populate() -> void:
	_queue.clear()
	for group: Node in groups.get_children():
		group.queue_free()
	
	var query: String = search.text.strip_edges().to_lower()
	var scored: Array[Array] = []
	for entry: ObjectRegistry.Entry in ObjectRegistry.get_entries():
		if not entry.browsable or (query.is_empty() and not _category.is_empty() and entry.category != _category):
			continue
		
		var score: int = _fuzzy_score(query, entry.display_name.to_lower()) if not query.is_empty() else 0
		if query.is_empty() or score > 0:
			scored.append([entry, score])
	
	scored.sort_custom(_compare)
	var group_view: LDObjectGroup
	var group_key: String = ""
	for pair: Array in scored:
		var entry: ObjectRegistry.Entry = pair.front()
		var key: String = "%s/%s" % [entry.category, entry.group]
		if key != group_key:
			group_key = key
			group_view = group_scene.instantiate()
			group_view.set_group_name(String(entry.group) if not entry.group.is_empty() else String(entry.category))
			groups.add_child(group_view)
		_queue.append([group_view, entry])
	
	if view.visible:
		_build(0)


func _build(budget_usec: int) -> void:
	var deadline: int = Time.get_ticks_usec() + budget_usec
	while not _queue.is_empty():
		var pair: Array = _queue.pop_front()
		var group_view: LDObjectGroup = pair.front()
		if is_instance_valid(group_view):
			var tile: LDObjectEntry = entry_scene.instantiate()
			tile.setup(pair.back())
			tile.pressed.connect(_on_entry_pressed.bind(tile.entry))
			Tooltip.set_text(tile, _highlight(search.text.strip_edges().to_lower(), tile.entry.display_name), Tooltip.Placement.UNDER)
			group_view.list.add_child(tile)
		
		if budget_usec > 0 and Time.get_ticks_usec() >= deadline:
			return


func _on_entry_pressed(entry: ObjectRegistry.Entry) -> void:
	SFX.play(SFX.LD_CONFIRM)
	picked.emit(entry)
	editor.tool_handler.arm(entry)
	close()


func _compare(a: Array, b: Array) -> bool:
	var first: ObjectRegistry.Entry = a.front()
	var second: ObjectRegistry.Entry = b.front()
	if first.category != second.category:
		return String(first.category) < String(second.category)
	if first.group != second.group:
		return String(first.group) < String(second.group)
	if a.back() != b.back():
		return a.back() > b.back()
	return first.display_name < second.display_name


func _fuzzy_score(query: String, text: String) -> int:
	if text == query:
		return 1000
	if text.begins_with(query):
		return 800
	if text.contains(query):
		return 600
	
	var matched: int = 0
	var last: int = -1
	var bonus: int = 0
	for i: int in text.length():
		if matched >= query.length():
			break
		if text.unicode_at(i) == query.unicode_at(matched):
			if last >= 0:
				bonus += maxi(0, 10 - (i - last))
			last = i
			matched += 1
	
	return 200 + bonus if matched == query.length() else 0


func _highlight(query: String, text: String) -> String:
	if query.is_empty():
		return text
	
	var lower: String = text.to_lower()
	var marked: Array[int] = []
	var start: int = lower.find(query)
	if start >= 0:
		marked.assign(range(start, start + query.length()))
	else:
		var matched: int = 0
		for i: int in lower.length():
			if matched < query.length() and lower.unicode_at(i) == query.unicode_at(matched):
				marked.append(i)
				matched += 1
	
	var colour: String = highlight_color.to_html(false)
	var result: String = ""
	for i: int in text.length():
		var character: String = text.substr(i, 1)
		result += "[color=#%s]%s[/color]" % [colour, character] if marked.has(i) else character
	
	return result
