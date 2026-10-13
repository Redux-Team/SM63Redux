extends PlayerState

@export var jumps: Array[JumpState]
@export var particles: AnimatedParticles

var _jump: JumpState
var _cut: bool = false


func _enter() -> void:
	var index: int = mini(player.jump_chain, jumps.size() - 1)
	while index > 0 and not jumps.get(index).can_chain():
		index -= 1
	
	_jump = jumps.get(index)
	_cut = false
	particles.burst()
	player.velocity.y = -_jump.strength
	player.jump_chain = index + 1
	player.jump_chain_timer = _jump.chain_window
	player.can_jump = false


func _tick(_delta: float) -> void:
	if _cut or player.velocity.y >= 0.0 or controls.is_held(&"jump"):
		return
	
	_cut = true
	player.velocity.y *= _jump.cut_multiplier


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if player.can_dive and time > 0.0 and controls.is_just_pressed(&"dive"):
		return &"Dive"
	if player.velocity.y > 0.0 and not player.is_on_floor():
		return &"Fall"
	if player.is_on_floor():
		return &"Idle"
	return _jump.name if is_current() else &""
