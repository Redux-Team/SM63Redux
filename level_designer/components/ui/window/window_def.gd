class_name LDWindowDef
extends Resource

## Describes one bindable window: the content scene plus the shell settings to apply
## when it is shown. LDUIWindowHandler holds a list of these instead of one node per
## window, and binds the shared LDWindow shell to the matching content on demand.

@export var id: StringName = &""
@export var scene: PackedScene
@export var title: String = ""
@export var close_on_back_input: bool = false
@export var window_scale: Vector2 = Vector2.ONE
