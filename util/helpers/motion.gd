class_name Motion

const LN2: float = 0.6931471805599453


static func rate(halflife: float) -> float:
	return LN2 / halflife if halflife > 0.0 else 0.0


static func approach(value: float, target: float, acceleration: float, delta: float) -> float:
	return move_toward(value, target, acceleration * delta)


static func damp(value: float, target: float, halflife: float, delta: float) -> float:
	if halflife <= 0.0:
		return value
	
	return lerpf(value, target, 1.0 - pow(2.0, -delta / halflife))


static func damp_angle(value: float, target: float, halflife: float, delta: float) -> float:
	if halflife <= 0.0:
		return value
	
	return lerp_angle(value, target, 1.0 - pow(2.0, -delta / halflife))


static func drift(value: float, acceleration: float, drag_rate: float, delta: float) -> float:
	if drag_rate <= 0.0:
		return value + acceleration * delta
	
	var rest: float = acceleration / drag_rate
	return rest + (value - rest) * exp(-drag_rate * delta)
