class_name IngameHUD
extends CanvasLayer

@export var health_gradient: Gradient
@export var inner_hp_texture: ColorRect
@export var inner_hpbg: TextureRect

var health_component: HealthComponent



func bind(entity: Entity) -> void:
	health_component = entity.get_component(HealthComponent)
	health_component.hp_updated.connect(_on_hp_updated)
	_on_hp_updated(health_component.get_hp())


func _on_hp_updated(amount: float) -> void:
	var mat: ShaderMaterial = inner_hp_texture.material as ShaderMaterial
	var total: float = health_component.max_hp
	var pct: float = amount / float(health_component.max_hp)
	var filled: int = roundi(pct * float(total))
	var col: Color = health_gradient.sample(1 - pct)
	mat.set_shader_parameter("total_slices", int(total))
	mat.set_shader_parameter("filled_slices", filled)
	mat.set_shader_parameter("modulate_color", col)
	inner_hpbg.modulate = col
