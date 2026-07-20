@tool
class_name EditorStateMachineEditor
extends Control

@export var graph_edit: GraphEdit
@export var state_machine_graph_edit: EditorStateMachineGraphEdit
@export var current_node_button: Button
@export var find_button: Button
@export var find_popup: PopupPanel
@export var find_from_option: OptionButton
@export var find_to_option: OptionButton
@export var find_results: ItemList

var _current_sm: StateMachine = null
var _find_entries: Array[Dictionary] = []
var _find_from_paths: Array[String] = []
var _find_to_paths: Array[String] = []


func _ready() -> void:
	if not find_button:
		return
	find_button.pressed.connect(_open_find_popup)
	find_from_option.item_selected.connect(_on_find_from_selected)
	find_to_option.item_selected.connect(_on_find_to_selected)
	find_results.item_selected.connect(_on_find_result_selected)
	find_results.item_activated.connect(_on_find_result_activated)


func load_state_machine(state_machine: StateMachine) -> void:
	_current_sm = state_machine
	if state_machine_graph_edit:
		state_machine_graph_edit._reload()
	if find_popup and find_popup.visible:
		find_popup.hide()
	_update_header()


func _update_header() -> void:
	if not current_node_button:
		return
	var label: String = "<empty>"
	if _current_sm:
		var node: Node = _current_sm.get_node_or_null(_current_sm.root_node)
		if node:
			label = String(node.name)
	current_node_button.text = label


func _is_plugin_instance() -> bool:
	return get_parent() is EditorDock


func _open_find_popup() -> void:
	if not _current_sm:
		return
	_populate_find_options(find_from_option, _find_from_paths, "")
	_populate_find_options(find_to_option, _find_to_paths, "")
	_refresh_find_results()
	var below: Vector2 = find_button.get_screen_position() + Vector2(0.0, find_button.size.y)
	find_popup.popup(Rect2i(Vector2i(below), Vector2i(620, 360)))


func _all_state_paths() -> Array[String]:
	var states: Array[State] = []
	_collect_states(_current_sm, states)
	var paths: Array[String] = []
	for s: State in states:
		paths.append(String(_current_sm.get_path_to(s)))
	paths.sort()
	return paths


func _collect_states(node: Node, out: Array[State]) -> void:
	for child: Node in node.get_children():
		if child is State:
			out.append(child)
			_collect_states(child, out)


func _populate_find_options(option: OptionButton, paths_out: Array[String], keep: String) -> void:
	option.clear()
	paths_out.clear()
	option.add_item("Any State")
	paths_out.append("")
	var selected: int = 0
	for path: String in _all_state_paths():
		paths_out.append(path)
		option.add_item(path)
		if path == keep:
			selected = paths_out.size() - 1
	option.select(selected)


func _find_from_filter() -> String:
	return _find_from_paths.get(find_from_option.selected) if find_from_option.selected >= 0 else ""


func _find_to_filter() -> String:
	return _find_to_paths.get(find_to_option.selected) if find_to_option.selected >= 0 else ""


func _on_find_from_selected(_index: int) -> void:
	_suggest_endpoints(find_to_option, _find_to_paths, _find_to_filter(), true)
	_refresh_find_results()


func _on_find_to_selected(_index: int) -> void:
	_suggest_endpoints(find_from_option, _find_from_paths, _find_from_filter(), false)
	_refresh_find_results()


func _suggest_endpoints(option: OptionButton, paths_out: Array[String], keep: String, suggest_targets: bool) -> void:
	var counts: Dictionary = {}
	for entry: Dictionary in _matching_transitions(_find_from_filter() if suggest_targets else "", "" if suggest_targets else _find_to_filter()):
		var path: String = String(entry.get("to_rel")) if suggest_targets else String(entry.get("from_rel"))
		counts[path] = int(counts.get(path, 0)) + 1
	option.clear()
	paths_out.clear()
	option.add_item("Any State")
	paths_out.append("")
	var selected: int = 0
	for path: String in _all_state_paths():
		if not counts.has(path) and path != keep:
			continue
		paths_out.append(path)
		option.add_item("%s (%d)" % [path, int(counts.get(path, 0))])
		if path == keep:
			selected = paths_out.size() - 1
	option.select(selected)


func _matching_transitions(from_filter: String, to_filter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _current_sm:
		return result
	var states: Array[State] = []
	_collect_states(_current_sm, states)
	for s: State in states:
		var from_rel: String = String(_current_sm.get_path_to(s))
		if not from_filter.is_empty() and from_rel != from_filter:
			continue
		for t: StateTransition in s.transitions:
			if not t:
				continue
			var target: State = _current_sm.get_node_or_null(t.target) as State
			var to_rel: String = String(_current_sm.get_path_to(target)) if target else "%s (missing)" % t.target
			if not to_filter.is_empty() and to_rel != to_filter:
				continue
			result.append({"state": s, "transition": t, "target": target, "from_rel": from_rel, "to_rel": to_rel})
	return result


func _refresh_find_results() -> void:
	find_results.clear()
	_find_entries = _matching_transitions(_find_from_filter(), _find_to_filter())
	for entry: Dictionary in _find_entries:
		var t: StateTransition = entry.get("transition")
		var idx: int = find_results.add_item("%s   →   %s      %s" % [entry.get("from_rel"), entry.get("to_rel"), _describe_transition(t)])
		find_results.set_item_tooltip(idx, _transition_tooltip(t))
		if not entry.get("target"):
			find_results.set_item_custom_fg_color(idx, Color(0.886, 0.294, 0.290))


func _describe_transition(t: StateTransition) -> String:
	var desc: String = ""
	match t.mode:
		StateTransition.TransitionMode.AUTO:
			desc = "auto"
		StateTransition.TransitionMode.WAIT_UNTIL_DONE:
			desc = "when done"
		StateTransition.TransitionMode.WAIT_UNTIL_EXPRESSION:
			desc = t.expression.replace("\n", " ").strip_edges()
			if desc.length() > 48:
				desc = desc.left(48) + "…"
	if t.min_delay > 0.0:
		desc += "  +%.2fs" % t.min_delay
	return desc


func _transition_tooltip(t: StateTransition) -> String:
	var lines: Array[String] = []
	lines.append(t.resource_name)
	lines.append("mode: %s" % StateTransition.TransitionMode.keys().get(t.mode))
	if not t.expression.is_empty():
		lines.append(t.expression)
	if t.min_delay > 0.0:
		lines.append("min_delay: %.2fs" % t.min_delay)
	if t.check_immediately:
		lines.append("check_immediately")
	return "\n".join(lines)


func _on_find_result_selected(index: int) -> void:
	_focus_find_entry(index)


func _on_find_result_activated(index: int) -> void:
	_focus_find_entry(index)
	find_popup.hide()


func _focus_find_entry(index: int) -> void:
	if index < 0 or index >= _find_entries.size():
		return
	var entry: Dictionary = _find_entries.get(index)
	var t: StateTransition = entry.get("transition")
	EditorInterface.inspect_object(t)
	if state_machine_graph_edit:
		state_machine_graph_edit.focus_transition(entry.get("state"), t, entry.get("target"))
