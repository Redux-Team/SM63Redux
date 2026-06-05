@icon("uid://c0xjm7d1vei2p")
class_name ForceBox
extends Area2D

enum ForceMode {
	REPULSION,  ## Pushes overlapping boxes away from the center
	ATTRACTION, ## Pulls overlapping boxes toward the center
}

enum AxisRestriction {
	BOTH,   ## Applies force freely across X and Y vectors
	X_ONLY, ## Locks force processing strictly to the Horizontal axis
	Y_ONLY, ## Locks force processing strictly to the Vertical axis
}

@export_group("Identity & Filtering")
## Unique identifiers to categorize what group this ForceBox belongs to (e.g. "enemy", "hazard").
@export var force_ids: Array[String] = []
## ForceBox IDs that this specific box will completely ignore.
@export var ignored_force_ids: PackedStringArray = []

@export_group("Force Configuration")
@export var force_mode: ForceMode = ForceMode.REPULSION
@export var axis_restriction: AxisRestriction = AxisRestriction.BOTH
## Base force multiplier applied to the target entity's velocity.
@export var force_magnitude: float = 1200.0
## Maps force intensity precisely over distance. 
## Left side (0.0) represents the absolute center; Right side (1.0) represents the outer bounds.
@export var force_curve: Curve

@export_group("Fixed Force Override")
## If enabled, ignores spatial center points and applies a constant structural vector 
## (e.g., behaving like a wind tunnel, zone-wide conveyer belt, or fan).
@export var use_fixed_vector: bool = false
@export var fixed_vector: Vector2 = Vector2.ZERO

var _overlapping_boxes: Array[ForceBox] = []


func _init() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 6


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if _overlapping_boxes.is_empty():
		return
		
	for other: ForceBox in _overlapping_boxes:
		if not is_instance_valid(other):
			continue
			
		_apply_continuous_force(other, delta)


func _on_area_entered(area: Area2D) -> void:
	if area == self or area is not ForceBox:
		return
		
	var other_box: ForceBox = area as ForceBox
	
	if other_box.force_ids.any(func(id: String) -> bool: return id in ignored_force_ids):
		return
		
	if not other_box in _overlapping_boxes:
		_overlapping_boxes.append(other_box)


func _on_area_exited(area: Area2D) -> void:
	if area is ForceBox:
		_overlapping_boxes.erase(area as ForceBox)


func _apply_continuous_force(target_box: ForceBox, delta: float) -> void:
	var target_owner: Node = target_box.owner
	if not target_owner or not ("velocity" in target_owner):
		return
		
	var direction: Vector2 = Vector2.ZERO
	var current_distance: float = global_position.distance_to(target_box.global_position)
	var max_radius: float = _get_max_radius()
	
	if use_fixed_vector:
		direction = fixed_vector.normalized()
	else:
		if current_distance < 0.001:
			direction = Vector2.RIGHT.rotated(randf() * TAU)
		else:
			direction = global_position.direction_to(target_box.global_position)
			if force_mode == ForceMode.ATTRACTION:
				direction = -direction
	
	match axis_restriction:
		AxisRestriction.X_ONLY:
			direction.y = 0.0
			if direction.x != 0.0:
				direction = direction.normalized()
		AxisRestriction.Y_ONLY:
			direction.x = 0.0
			if direction.y != 0.0:
				direction = direction.normalized()
	
	var intensity: float = 1.0
	if force_curve and max_radius > 0.0:
		var normalized_distance: float = clampf(current_distance / max_radius, 0.0, 1.0)
		intensity = force_curve.sample(normalized_distance)
	
	var force_vector: Vector2 = direction * (force_magnitude * intensity)
	
	target_owner.velocity += force_vector * delta


func _get_max_radius() -> float:
	for child: Node in get_children():
		if child is CollisionShape2D and is_instance_valid(child) and not child.disabled:
			var shape: Shape2D = child.shape
			if shape is CircleShape2D:
				return shape.radius
			elif shape is RectangleShape2D:
				return shape.size.length() * 0.5
			elif shape is CapsuleShape2D:
				return shape.height * 0.5
	return 100.0


func enable() -> void:
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", false)
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", true)


func disable() -> void:
	_overlapping_boxes.clear()
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", true)
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
