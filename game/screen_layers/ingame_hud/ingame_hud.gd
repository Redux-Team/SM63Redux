class_name IngameHUD
extends CanvasLayer

@export var hp_label: Label

var health_component: HealthComponent

func bind(entity: Entity) -> void:
	health_component = entity.get_component(HealthComponent)
	health_component.damaged.connect(_on_damaged)


func _on_damaged(_amount, _type) -> void:
	hp_label.text = str(int(health_component.get_hp()))
