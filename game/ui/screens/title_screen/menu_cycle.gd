extends Control

@export var menu_buttons: Array[MainMenuButton]
@export var animation_player: AnimationPlayer
@export var left_button_container: AspectRatioContainer
@export var center_button_container: AspectRatioContainer
@export var right_button_container: AspectRatioContainer
@export var extra_button_container: AspectRatioContainer
@export var menu_buttons_holder: Control
@export var sfx_next: AudioStreamPlayer

var current_index: int = 0
var is_cycling: bool = false

func _ready() -> void:
	assign_buttons_to_containers()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		cycle(1, &"cycle_right")
	elif event.is_action_pressed(&"ui_left"):
		cycle(-1, &"cycle_left")


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


func cycle(direction: int, animation_name: StringName) -> void:
	if is_cycling or animation_player.is_playing() or not is_visible_in_tree():
		return
	
	is_cycling = true
	
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
	
	is_cycling = false


func _input_cycle_region(event: InputEvent, direction: int, animation: StringName) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton and event.is_pressed():
		cycle(direction, animation)
