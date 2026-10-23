class_name LDTouchInput
extends LDComponent

var _touches: Dictionary[int, Vector2] = {}


func handle_input(event: InputEvent) -> bool:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		
		if touch.pressed and _touches.size() == 2:
			editor.tool_handler.cancel()
		return is_gesturing()
	
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag and _touches.has(drag.index) and is_gesturing():
		var before: Array[Vector2] = _pair()
		_touches[drag.index] = drag.position
		var after: Array[Vector2] = _pair()
		var camera: LDCameraControl = editor.viewport_handler.camera_control
		camera.pan((before.front() + before.back()) / 2.0 - (after.front() + after.back()) / 2.0)
		var spread: float = before.front().distance_to(before.back())
		if spread > 0.0:
			camera.zoom_at(
					after.front().distance_to(after.back()) / spread,
					(after.front() + after.back()) / 2.0,
			)
		return true
	
	return is_gesturing() and event is InputEventMouse


func is_gesturing() -> bool:
	return _touches.size() >= 2


func _pair() -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.assign(_touches.values().slice(0, 2))
	return points
