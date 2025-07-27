@tool
class_name SliderSettingEntry
extends SettingEntry

signal toggled(value: bool)
signal value_changed(value: float)
signal drag_ended

enum ToggleValue {
	NO_TOGGLE,
	ON,
	OFF,
}

enum ValueType {
	NONE,
	VALUE,
	PERCENT,
	MULTIPLIER,
	CUSTOM,
}

@export var _toggle: ToggleValue
@export var value_type: ValueType
@export var silent: bool = true
@export var ticks: int = 0:
	set(t):
		slider.tick_count = t
		ticks = t

var value_slider_callable: Callable

@export_group("Slider")
@export var slider_min: float = 0.0:
	set(sm):
		slider.min_value = sm
		slider_min = sm
@export var slider_max: float = 100.0:
	set(sm):
		slider.max_value = sm
		slider_max = sm
@export var slider_value: float = 75.0:
	set(sv):
		slider.value = sv
		slider_value = sv
		_update_value_text()
@export var slider_step: float = 1.0:
	set(ss):
		slider.step = ss
		slider_step = ss

@export_group("Internal")
@export var boolean_widget: BooleanWidget
@export var slider: HSlider
@export var interaction: Button
@export var setting_name_label: Label
@export var value_label: Label

var interaction_hovering: bool = false
var interaction_focused: bool = false
var interaction_pressed: bool = false


func _ready() -> void:
	setting_name_changed.connect(_on_setting_name_changed)
	
	_assign_toggle()
	_update_slider()
	
	setting_name_label.text = setting_name


func set_toggle(value: bool, play_sfx: bool = true) -> void:
	_toggle = ToggleValue.ON if value else ToggleValue.OFF
	boolean_widget.set_toggled(value, play_sfx)
	_update_slider()


func _assign_toggle() -> void:
	boolean_widget.show()
	interaction.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interaction.focus_mode = Control.FOCUS_ALL
	
	match _toggle:
		ToggleValue.NO_TOGGLE:
			boolean_widget.hide()
			interaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
			interaction.mouse_default_cursor_shape = Control.CURSOR_ARROW
			interaction.focus_mode = Control.FOCUS_NONE
		ToggleValue.ON:
			boolean_widget.set_toggled(true, false)
		ToggleValue.OFF:
			boolean_widget.set_toggled(false, false)


func _update_slider() -> void:
	slider.modulate = Color.WHITE
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if _toggle == ToggleValue.OFF:
		slider.modulate = Color.DIM_GRAY
		slider.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_value_text() -> void:
	var value_text: String = ""
	
	match value_type:
		ValueType.NONE:
			pass
		ValueType.VALUE:
			value_text = "%.2f" % slider_value
		ValueType.PERCENT:
			value_text = "%s%%" % int(slider_value)
		ValueType.MULTIPLIER:
			value_text = "%.2fx" % slider_value
		ValueType.CUSTOM:
			value_text = value_slider_callable.call(slider_value)
	
	value_label.text = value_text


func _update_text_color() -> void:
	setting_name_label.add_theme_color_override(&"font_color", Color.WHITE)
	
	if interaction_hovering or interaction_focused:
		setting_name_label.add_theme_color_override(&"font_color", Color.YELLOW)
	if interaction_pressed:
		setting_name_label.add_theme_color_override(&"font_color", Color.AQUA)


func _on_interaction_mouse_entered() -> void:
	interaction_hovering = true
	_update_text_color()


func _on_interaction_mouse_exited() -> void:
	interaction_hovering = false
	_update_text_color()


func _on_interaction_focus_entered() -> void:
	interaction_focused = true
	_update_text_color()


func _on_interaction_focus_exited() -> void:
	interaction_focused = false
	_update_text_color()


func _on_interaction_button_down() -> void:
	interaction_pressed = true
	_update_text_color()


func _on_interaction_button_up() -> void:
	interaction_pressed = false
	_update_text_color()


func _on_interaction_pressed() -> void:
	boolean_widget.set_toggled(not boolean_widget._get_checkbox_value(), true)


func _on_boolean_widget_value_changed(value: bool) -> void:
	_toggle = ToggleValue.ON if value else ToggleValue.OFF
	
	if not Engine.is_editor_hint():
		toggled.emit(value)
	
	_update_slider()
	_update_text_color()


func _on_slider_value_changed(value: float) -> void:
	slider_value = value
	
	if not Engine.is_editor_hint():
		value_changed.emit(value)


func _on_setting_name_changed(value: StringName) -> void:
	setting_name_label.text = value


func _on_slider_drag_ended(_value_changed: bool) -> void:
	if not silent:
		SFX.play(SFX.UI_NEXT)
	drag_ended.emit()
