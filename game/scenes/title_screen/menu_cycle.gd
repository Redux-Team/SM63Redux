extends Control

@export var menu_buttons: Array[MainMenuButton]
@export var animation_player: AnimationPlayer
@export var left_button_container: AspectRatioContainer
@export var center_button_container: AspectRatioContainer
@export var right_button_container: AspectRatioContainer
@export var extra_button_container: AspectRatioContainer
@export var selector_arrow: TextureRect
@export var menu_buttons_holder: Control
@export var description_label: Label
@export var scene_transition: Node

var current_index: int = 0

func _ready() -> void:
	for menu_button: MainMenuButton in menu_buttons:
		menu_button.interaction.connect(func() -> void:
			scene_transition.transition(menu_buttons[current_index].content)
		)
	
	assign_buttons_to_containers()
	update_description()
	animate_selector()


func _input(event: InputEvent) -> void:
	if owner.input_locked:
		return
	
	if event.is_action_pressed(&"_ui_right"):
		cycle(1, &"cycle_right")
	elif event.is_action_pressed(&"_ui_left"):
		cycle(-1, &"cycle_left")
	
	if event.is_action_pressed(&"_ui_interact") and not animation_player.is_playing() and is_visible_in_tree():
		scene_transition.transition(menu_buttons[current_index].content)


## Reparenting logic for the main menu buttons so that the AnimationPlayer can reuse the same
## containers every cycle.
func assign_buttons_to_containers() -> void:
	for button in menu_buttons:
		if button.get_parent() != menu_buttons_holder:
			button.reparent(menu_buttons_holder)
	
	var total = menu_buttons.size()
	var positions = [
		(current_index - 1 + total) % total,  # left
		current_index,                        # center
		(current_index + 1) % total,          # right
		(current_index + 2) % total           # extra
	]
	
	var containers = [
		left_button_container,
		center_button_container, 
		right_button_container,
		extra_button_container
	]
	
	for i in range(4):
		var button = menu_buttons[positions[i]]
		button.reparent(containers[i])
		button.show()


## The logic which combines the animation with the reparenting, ensuring that no reparenting
## happens if the next animation is not ready. 
func cycle(direction: int, animation_name: StringName) -> void:
	if animation_player.is_playing() or not is_visible_in_tree():
		return
	
	SFX.play(SFX.UI_NEXT)
	
	current_index = (current_index + direction + menu_buttons.size()) % menu_buttons.size()
	animation_player.play(animation_name)
	
	if sign(direction) == -1: # bandaid fix for going left
		var next_index: int = (current_index + direction + menu_buttons.size()) % menu_buttons.size()
		extra_button_container.get_child(0).reparent(menu_buttons_holder)
		menu_buttons[next_index].reparent(extra_button_container)
	
	await animation_player.animation_finished
	animation_player.play(&"RESET")
	await get_tree().process_frame
	assign_buttons_to_containers()


## Handles cycling when the side regions are clicked or touched
func _input_cycle_region(event: InputEvent, direction: int, animation: StringName) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton and event.is_pressed():
		cycle(direction, animation)


## Called via animation, this is what grabs the description from the current button and updates
## the label when it is invisible.
func update_description() -> void:
	var button: MainMenuButton = menu_buttons[current_index]
	description_label.text = button.description


func animate_selector() -> void:
	var tween: Tween = get_tree().create_tween()
	
	var mat: Material = selector_arrow.material
	var target: MainMenuButton = menu_buttons[current_index]
	
	tween.tween_property(mat, ^"shader_parameter/saturation_scale", target.saturation, 0.08)
	
	var start_hue: float = mat.get_shader_parameter(&"hue_shift")
	var end_hue: float = target.hue
	var shortest_hue: float = shortest_hue_target(start_hue, end_hue)
	
	tween.tween_method(_set_hue_shift, start_hue, shortest_hue, 0.02)
	
	if target.disabled:
		tween.tween_property(mat, ^"shader_parameter/value_scale", target.value - 0.75, 0.05)
	else:
		tween.tween_property(mat, ^"shader_parameter/value_scale", target.value, 0.08)


func shortest_hue_target(start: float, target: float) -> float:
	var delta: float = fmod(target - start + 1.5, 1.0) - 0.5
	return start + delta


func _set_hue_shift(value: float) -> void:
	selector_arrow.material.set_shader_parameter("hue_shift", fmod(value, 1.0))
