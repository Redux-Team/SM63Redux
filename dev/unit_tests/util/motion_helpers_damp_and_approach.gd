@tool
static func run_test() -> void:
	assert(is_equal_approx(Motion.rate(1.0), log(2.0)))
	assert(is_equal_approx(Motion.rate(0.5), 2.0 * log(2.0)))
	assert(Motion.rate(0.0) == 0.0)
	assert(Motion.rate(-1.0) == 0.0)
	
	assert(is_equal_approx(Motion.approach(0.0, 10.0, 20.0, 0.25), 5.0))
	assert(is_equal_approx(Motion.approach(0.0, 10.0, 100.0, 1.0), 10.0))
	assert(is_equal_approx(Motion.approach(10.0, -10.0, 4.0, 1.0), 6.0))
	
	assert(is_equal_approx(Motion.damp(0.0, 100.0, 0.2, 0.2), 50.0))
	assert(is_equal_approx(Motion.damp(0.0, 100.0, 0.2, 0.4), 75.0))
	assert(Motion.damp(3.0, 100.0, 0.0, 1.0) == 3.0)
	assert(Motion.damp(5.0, 5.0, 0.1, 0.016) == 5.0)
	
	var stepped: float = 0.0
	for i: int in 10:
		stepped = Motion.damp(stepped, 100.0, 0.2, 0.02)
	assert(is_equal_approx(stepped, Motion.damp(0.0, 100.0, 0.2, 0.2)))
	
	var across: float = Motion.damp_angle(deg_to_rad(170.0), deg_to_rad(-170.0), 0.1, 0.1)
	assert(is_equal_approx(absf(wrapf(across, -PI, PI)), PI))
	assert(Motion.damp_angle(1.0, 2.0, 0.0, 1.0) == 1.0)
	
	assert(is_equal_approx(Motion.drift(2.0, 10.0, 0.0, 0.5), 7.0))
	assert(is_equal_approx(Motion.drift(4.0, 8.0, 2.0, 0.3), 4.0))
	assert(is_equal_approx(Motion.drift(0.0, 8.0, 2.0, 100.0), 4.0))
	var drifting: float = Motion.drift(0.0, 8.0, 2.0, 0.5)
	assert(drifting > 0.0 and drifting < 4.0)
	assert(is_equal_approx(Motion.drift(drifting, 8.0, 2.0, 0.5), Motion.drift(0.0, 8.0, 2.0, 1.0)))
