extends PlayerState

const FULL_DURATION: float = 18
const HANG_DURATION: float = 9
const SPIN_DURATION: float = FULL_DURATION - HANG_DURATION

# Sprite origin is set to this during pound spin
const SPIN_ORIGIN := Vector2(-2,-3)
const SPIN_EASE_CURVE: float = 0.5

## How many frames the player will be rising during the pound spin.
const RISE_TIME: float = 15
## How much the player rises each frame.
const RISE_RATE: float = 1

var progress: float


func _on_enter(_h):
	_anim(&"flip")
	progress = 0.0
	motion.set_vel(Vector2.ZERO)
	actor.sprite.set_rotation_origin(motion.get_facing(), SPIN_ORIGIN)


func _all_ticks():
	progress += 1.0
	
	# Animation of the player doing a flip to wind up for the pound.
	# Spin faster towards the start, slowing as progress nears SPIN_DURATION.
	if progress <= SPIN_DURATION:
		var spin_fac = ease(progress / SPIN_DURATION, SPIN_EASE_CURVE)
		motion.set_rotation(spin_fac * TAU * motion.get_facing())
	
	# A little rising during the wind-up makes it look real nice.
	# This feels best if it affects the literal, physical position of the player
	# (so that when they appear to rise above a platform, they actually do).
	if progress <= RISE_TIME:
		motion.set_vel_component(Vector2.DOWN, -RISE_RATE)


func _on_exit():
	# Revert altered rotation origin.
	actor.sprite.clear_rotation_origin()


func _trans_rules():
	if progress > FULL_DURATION:
		return &"PoundFall"
	return &""
