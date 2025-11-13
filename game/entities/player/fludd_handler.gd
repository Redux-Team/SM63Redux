extends StateProcess

const FLUDD_SPEED: float = -300.0
const FLUDD_BOOST_SPEED: float = -120.0
const FLUDD_SNAP_UP: float = 0.3
const FLUDD_SMOOTH_UP: float = 0.1
const FLUDD_VELOCITY_THRESHOLD: float = -100.0

const FLUDD_DIVE_VERTICAL_ACCEL: float = 1012.0
const FLUDD_DIVE_HORIZONTAL_ACCEL: float = 1200.0
const FLUDD_DIVE_DAMPING_X: float = 0.97
const FLUDD_DIVE_DAMPING_Y: float = 0.98 

var dive_boost: bool = false

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("use_fludd"):
		player.is_using_hover_fludd = true
		if player.is_in_water:
			player.velocity.y = lerpf(player.velocity.y, -270, 0.2)
			return
		
		if state_machine.current_state.name in [&"Dive", &"Floorslide"]:
			player.velocity.x *= FLUDD_DIVE_DAMPING_X
			player.velocity.y *= FLUDD_DIVE_DAMPING_Y
			
			var rotation: float = player.sprite.rotation
			
			var vertical_accel: float = sin(rotation) * FLUDD_DIVE_VERTICAL_ACCEL * delta
			var horizontal_accel: float = cos(rotation) * FLUDD_DIVE_HORIZONTAL_ACCEL * delta
			
			var facing: float = 1.0 if not player.sprite.flip_h else -1.0
			
			player.velocity.y += vertical_accel * facing
			player.velocity.x += (horizontal_accel + (30.5 if player.is_on_floor() else 0.0)) * facing
		else:
			if player.velocity.y < FLUDD_VELOCITY_THRESHOLD:
				player.velocity.x = clampf(player.velocity.x, -player.run_max_speed / 1.2, player.run_max_speed / 1.2)
				return
			
			if player.velocity.y > 0.0:
				player.velocity.y = lerpf(player.velocity.y, FLUDD_BOOST_SPEED, FLUDD_SNAP_UP)
			else:
				player.velocity.y = lerpf(player.velocity.y, FLUDD_SPEED, FLUDD_SMOOTH_UP)
			
			player.velocity.y = max(player.velocity.y, FLUDD_BOOST_SPEED)
			player.velocity.x = clampf(player.velocity.x, -player.run_max_speed / 1.2, player.run_max_speed / 1.2)
	else:
		player.is_using_hover_fludd = false
