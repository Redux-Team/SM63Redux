extends PropertyWidget

const CHIP_CLASS: String = "Chip"

@export var label: Label
@export var chips: HFlowContainer

var _bits: Array[int] = []


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	for chip: Node in chips.get_children():
		chip.queue_free()
	_bits.clear()
	var bit: int = 1
	for entry: String in String(widget_info.get("hint_string", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() > 1:
			bit = parts[1].to_int()
		var chip: Button = Button.new()
		chip.text = parts[0]
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.toggled.connect(_on_toggled.unbind(1))
		GDSS.add_class(chip, CHIP_CLASS)
		chips.add_child(chip)
		_bits.append(bit)
		bit <<= 1


func _value(widget_value: Variant) -> void:
	var mask: int = int(widget_value)
	for i: int in _bits.size():
		(chips.get_child(i) as Button).set_pressed_no_signal(mask & _bits[i] != 0)


func _on_toggled() -> void:
	var mask: int = 0
	for i: int in _bits.size():
		if (chips.get_child(i) as Button).button_pressed:
			mask |= _bits[i]
	
	_commit(mask)
