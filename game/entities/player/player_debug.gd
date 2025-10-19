extends VBoxContainer

@export var debug_label: Label
var player: Player:
	get():
		return owner



func _process(delta: float) -> void:
	var debug_text: String = ""
	
	debug_text += "Current State: %s\n" % player.state_machine.current_state 
	debug_text += "Current Animation: %s\n" % player.state_machine.sprite.animation 
	debug_text += "is_jumping: %s\n" % player.is_jumping 
	debug_text += "is_falling: %s\n" % player.is_falling 
	debug_text += "is_running: %s\n" % player.is_running 
	debug_text += "move_dir: %s\n" % player.move_dir 
	debug_text += "current_jump: %s\n" % player.current_jump 
	debug_text += "jump_chain_timer: %s\n" % player.jump_chain_timer
	debug_text += "is_on_floor: %s\n" % player.is_on_floor()
	debug_text += "Velocity: %s\n" % player.velocity 
	
	
	debug_label.text = debug_text
