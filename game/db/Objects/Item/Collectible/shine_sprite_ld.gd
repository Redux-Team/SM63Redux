@tool
extends LDObjectSprite

@export var sprite: SmartSprite2D
@export var scenario_label: Label
var scenario_id: int:
	set(si):
		scenario_label.text = str(si)
		scenario_id = si


func _ready() -> void:
	sprite.play(&"spin")


func _on_place() -> void:
	super()
	scenario_label.show()
