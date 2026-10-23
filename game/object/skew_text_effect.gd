class_name SkewTextEffect
extends RichTextEffect

const SKEW: float = 0.25

var bbcode: String = "skew"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	char_fx.transform = \
			char_fx.transform * Transform2D(Vector2.RIGHT, Vector2(-SKEW, 1.0), Vector2.ZERO)
	return true
