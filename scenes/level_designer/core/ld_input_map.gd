@tool
class_name LDInputMap
extends Resource

@export var shortcuts: Array[LDShortcut]


func apply() -> void:
	for shortcut: LDShortcut in shortcuts:
		if InputMap.has_action(shortcut.action):
			continue
		
		InputMap.add_action(shortcut.action)
		for event: InputEvent in shortcut.events:
			InputMap.action_add_event(shortcut.action, event)
