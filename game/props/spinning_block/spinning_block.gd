class_name SpinningBlock
extends Prop

@export var rect: Control
@export var body: Node2D


static func get_degrees(elapsed: float, speed: float, wait: float) -> float:
	if is_zero_approx(speed):
		return 0.0
	
	var cycle: float = 1.0 / absf(speed)
	var wait_cycle: float = cycle + wait
	var phase: float = fmod(elapsed, wait_cycle)
	var base: float = 90.0 * floori(elapsed / wait_cycle) * signf(speed)
	var progress: float = clampf((phase - wait) / cycle, 0.0, 1.0)
	return wrapf(base + 90.0 * signf(speed) * progress, 0.0, 360.0)


func _physics_process(_delta: float) -> void:
	var level: Level = Level.of(self)
	var elapsed: float = level.get_time() if level else Time.get_ticks_msec() / 1000.0
	var degrees: float = get_degrees(
			elapsed,
			get_property(&"b_rotate_speed", 1.0),
			get_property(&"b_wait_time", 2.0),
	)
	rect.rotation_degrees = degrees
	body.rotation_degrees = degrees
