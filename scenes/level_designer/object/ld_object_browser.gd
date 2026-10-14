class_name LDObjectBrowser
extends LDPanel

signal picked(entry: ObjectRegistry.Entry)

enum Scope { BOTH, ALL, CATEGORY }

const CHIP_CLASS: String = "Chip"
const LEADING_CATEGORY: StringName = &"Solids"

@export var search: LineEdit
@export var category_bar: HBoxContainer
@export var groups: VBoxContainer
@export var group_scene: PackedScene
@export var entry_scene: PackedScene
@export var highlight_color: Color = Color("3da4ff")
@export var build_budget_usec: int = 4000

var _category: StringName = &""
var _chips: ButtonGroup = ButtonGroup.new()
var _queue: Array[ObjectRegistry.Entry] = []
var _sections: Dictionary[String, LDObjectGroup] = {}
var _tiles: Array[LDObjectEntry] = []
var _query: String = ""
var _searched: bool = false


func _setup() -> void:
	super()
	_chips.pressed.connect(_on_chip_pressed)
	search.text_changed.connect(_on_search_changed)
	_build_chips()
	_queue.assign(ObjectRegistry.get_entries().filter(func(entry: ObjectRegistry.Entry) -> bool: return entry.browsable))
	_queue.sort_custom(_compare)
	_build_sections()


func _process(_delta: float) -> void:
	if _queue.is_empty():
		set_process(false)
		return
	
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
	_filter()
	if is_open():
		editor.interface_handler.window.set_title(get_title())


func _on_search_changed(text: String) -> void:
	_query = text.strip_edges().to_lower()
	_filter()


func _build_sections() -> void:
	var primary: Dictionary[String, String] = {}
	for entry: ObjectRegistry.Entry in _queue:
		for section: String in [_all_section(entry), _category_section(entry)]:
			if not primary.has(section) or String(entry.category) < primary.get(section):
				primary.set(section, String(entry.category))
	
	var names: Array[String] = primary.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return primary.get(a) < primary.get(b) if primary.get(a) != primary.get(b) else a < b)
	for section: String in names:
		var group_view: LDObjectGroup = group_scene.instantiate()
		group_view.set_group_name(section)
		group_view.visible = false
		groups.add_child(group_view)
		_sections.set(section, group_view)


func _build(budget_usec: int) -> void:
	var deadline: int = Time.get_ticks_usec() + budget_usec
	while not _queue.is_empty():
		var entry: ObjectRegistry.Entry = _queue.pop_front()
		var all_section: String = _all_section(entry)
		var category_section: String = _category_section(entry)
		if all_section == category_section:
			_add_tile(entry, all_section, Scope.BOTH)
		else:
			_add_tile(entry, all_section, Scope.ALL)
			_add_tile(entry, category_section, Scope.CATEGORY)
		if budget_usec > 0 and Time.get_ticks_usec() >= deadline:
			return


func _add_tile(entry: ObjectRegistry.Entry, section: String, scope: Scope) -> void:
	var group_view: LDObjectGroup = _sections.get(section)
	var tile: LDObjectEntry = entry_scene.instantiate()
	tile.setup(entry)
	tile.pressed.connect(_on_entry_pressed.bind(entry))
	tile.set_meta(&"group", group_view)
	tile.set_meta(&"scope", scope)
	Tooltip.set_text(tile, entry.display_name, Tooltip.Placement.UNDER)
	group_view.list.add_child(tile)
	_tiles.append(tile)
	_apply_filter(tile)
	if tile.visible:
		group_view.visible = true


func _filter() -> void:
	var shown: Dictionary[LDObjectGroup, bool] = {}
	for tile: LDObjectEntry in _tiles:
		_apply_filter(tile)
		if tile.visible:
			shown.set(tile.get_meta(&"group"), true)
	
	for group_view: LDObjectGroup in _sections.values():
		group_view.visible = shown.has(group_view)
		if _searched or not _query.is_empty():
			_sort_group(group_view)
	_searched = not _query.is_empty()


static func _all_section(entry: ObjectRegistry.Entry) -> String:
	return String(entry.biome) if not entry.biome.is_empty() else _category_section(entry)


static func _category_section(entry: ObjectRegistry.Entry) -> String:
	return String(entry.group) if not entry.group.is_empty() else String(entry.category)


func _apply_filter(tile: LDObjectEntry) -> void:
	var entry: ObjectRegistry.Entry = tile.entry
	var scope: Scope = tile.get_meta(&"scope")
	if _query.is_empty():
		tile.visible = scope != Scope.CATEGORY if _category.is_empty() else scope != Scope.ALL and entry.category == _category
		tile.set_meta(&"score", 0)
		Tooltip.set_text(tile, entry.display_name, Tooltip.Placement.UNDER)
		return
	
	var score: int = _fuzzy_score(_query, entry.display_name.to_lower()) if scope != Scope.CATEGORY else 0
	tile.visible = score > 0
	tile.set_meta(&"score", score)
	if tile.visible:
		Tooltip.set_text(tile, _highlight(_query, entry.display_name), Tooltip.Placement.UNDER)


func _sort_group(group_view: LDObjectGroup) -> void:
	var tiles: Array[Node] = group_view.list.get_children()
	var sorted: Array[Node] = tiles.duplicate()
	sorted.sort_custom(func(a: Node, b: Node) -> bool: return _compare_tiles(a as LDObjectEntry, b as LDObjectEntry))
	if sorted == tiles:
		return
	
	for i: int in sorted.size():
		group_view.list.move_child(sorted.get(i), i)


func _compare_tiles(a: LDObjectEntry, b: LDObjectEntry) -> bool:
	var score_a: int = a.get_meta(&"score", 0)
	var score_b: int = b.get_meta(&"score", 0)
	if score_a != score_b:
		return score_a > score_b
	
	return _compare(a.entry, b.entry)


func _on_entry_pressed(entry: ObjectRegistry.Entry) -> void:
	SFX.play(SFX.LD_CONFIRM)
	picked.emit(entry)
	editor.tool_handler.arm(entry)
	close()


func _compare(first: ObjectRegistry.Entry, second: ObjectRegistry.Entry) -> bool:
	if first.category != second.category:
		return first.category == LEADING_CATEGORY or (second.category != LEADING_CATEGORY and String(first.category) < String(second.category))
	if first.order != second.order:
		return first.order < second.order
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
