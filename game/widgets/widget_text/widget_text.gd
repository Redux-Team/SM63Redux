extends PropertyWidget

@export var label: Label
@export var text_edit: TextEdit
@export var preview: RichTextLabel
@export var font: Font
@export var bold_font: Font


func _ready() -> void:
	TextDisplay.apply_fonts(preview, font, bold_font)
	text_edit.text_changed.connect(
			func() -> void: preview.text = TextDisplay.format(text_edit.text)
	)
	text_edit.focus_exited.connect(func() -> void: _commit(text_edit.text))


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	preview.visible = widget_info.get("bbcode", false)


func _value(widget_value: Variant) -> void:
	if not text_edit.has_focus():
		text_edit.text = str(widget_value)
		preview.text = TextDisplay.format(text_edit.text)
