class_name LDUI
extends CanvasLayer

static var focus_window_open: bool:
	set(fwo):
		
		focus_window_open = fwo

@export var ld_window: LDWindow



func _ready() -> void:
	(ld_window.get_content_ref() as LDObjectBrowser).category_changed.connect(func(n: String) -> void:
		ld_window.title = "Objects - " + (n if n else "All")
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.is_pressed():
			if ld_window.visible:
				ld_window.popout()
				focus_window_open = false
			else:
				ld_window.popin()
				focus_window_open = true
