extends State

@export var swim_up_strength: float = 350.0
@export var gravity: float = 100.0
@export var gravity_boost: float = 3.0
@export var boost_duration: float = 0.2 

var boost_timer: float = 0.0

func _on_enter(_from: StringName) -> void:
	player.velocity.y = -swim_up_strength
	boost_timer = boost_duration
	player.swim_buffer_time = 0.2


func _physics_process(delta: float) -> void:
	if player.velocity.y < 0:
		player.velocity.y = lerpf(player.velocity.y, 0, 0.1)
	player.swim_buffer_time = max(player.swim_buffer_time - delta, 0)
