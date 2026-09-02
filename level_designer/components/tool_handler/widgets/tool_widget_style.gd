class_name LDToolWidgetStyle
extends Resource

## Look of a single [LDToolHandle]. One resource per kind of handle (polygon vertex, block
## corner, path head, ...), living under assets/textures/level_designer/tool_widgets so the art
## can be retuned without touching a tool script.

enum State {
	NORMAL,
	HOVER,
	PRESSED,
	HOVER_PRESSED,
	DISABLED,
}

## How a handle sizes itself against the camera. Declared here, on the leaf resource, so the
## widget and its handle sets can both name it without depending on each other.
enum RenderSpace {
	## Screen space: constant pixel size whatever the zoom. What every editor gizmo wants.
	GLOBAL,
	## World space: the handle zooms with the level, like the geometry it sits on.
	LOCAL,
	## World space, but never smaller or larger than the style's screen bounds.
	LOCAL_CLAMPED,
}


@export_group("Textures")
@export var normal: Texture2D
## Falls back to [member normal] when unset, and so on down the list.
@export var hover: Texture2D
@export var pressed: Texture2D
@export var hover_pressed: Texture2D
@export var disabled: Texture2D

@export_group("Metrics")
## Size the handle draws at, in screen pixels, before the owning widget's render space is applied.
@export var size: Vector2 = Vector2(12.0, 12.0)
## Screen-space radius the owning widget grabs this handle within. Deliberately separate from
## [member size]: most handles are easier to grab than they look, the topline dots are harder.
@export var grab_radius: float = 18.0
## Only consulted in [constant RenderSpace.LOCAL_CLAMPED].
@export var min_screen_size: Vector2 = Vector2(6.0, 6.0)
@export var max_screen_size: Vector2 = Vector2(48.0, 48.0)

@export_group("Tint")
@export var tint: Color = Color.WHITE
@export var tint_disabled: Color = Color(0.5, 0.5, 0.55, 0.6)


func get_texture(state: LDToolWidgetStyle.State) -> Texture2D:
	match state:
		State.HOVER_PRESSED:
			return _first(hover_pressed, pressed, hover)
		State.PRESSED:
			return _first(pressed, hover_pressed, hover)
		State.HOVER:
			return _first(hover, hover_pressed, pressed)
		State.DISABLED:
			return _first(disabled, null, null)
	return normal


func get_tint(state: LDToolWidgetStyle.State) -> Color:
	return tint_disabled if state == State.DISABLED else tint


func _first(a: Texture2D, b: Texture2D, c: Texture2D) -> Texture2D:
	if a:
		return a
	if b:
		return b
	if c:
		return c
	return normal
