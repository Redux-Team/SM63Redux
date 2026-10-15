class_name TextDisplay
extends RichTextLabel

const ITALIC_TAGS: Dictionary[String, String] = {"[i]": "[i][skew]", "[/i]": "[/skew][/i]"}

@export var fonts: Array[Font] = []
@export var bold_fonts: Array[Font] = []


static func apply_fonts(label: RichTextLabel, font: Font, bold_font: Font) -> void:
	_set_font(label, &"normal", font)
	_set_font(label, &"mono", font)
	_set_font(label, &"italics", font)
	_set_font(label, &"bold", bold_font)
	_set_font(label, &"bold_italics", bold_font)
	if not label.custom_effects.any(func(effect: RichTextEffect) -> bool: return effect is SkewTextEffect):
		label.install_effect(SkewTextEffect.new())


static func format(content: String) -> String:
	var formatted: String = content
	for tag: String in ITALIC_TAGS:
		formatted = formatted.replace(tag, ITALIC_TAGS.get(tag))
	return formatted


static func _set_font(label: Control, slot: String, font: Font) -> void:
	label.add_theme_font_override(slot + "_font", font)
	var base: Font = (font as FontVariation).base_font if font is FontVariation else font
	var file: FontFile = base as FontFile
	if file and file.fixed_size > 0:
		label.add_theme_font_size_override(slot + "_font_size", file.fixed_size)


func _init() -> void:
	install_effect(SkewTextEffect.new())


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_fit.call_deferred()


func set_content(content: String) -> void:
	text = format(content)
	_fit()


func set_font_index(index: int) -> void:
	var at: int = clampi(index, 0, fonts.size() - 1)
	apply_fonts(self, fonts.get(at), bold_fonts.get(at))


func _fit() -> void:
	size = Vector2(get_content_width(), get_content_height()) + get_theme_stylebox(&"normal").get_minimum_size()
	position = -size * 0.5
	var object: GameObject = GameObject.of(self)
	if object:
		object.bounds_override = Rect2(position, size)
