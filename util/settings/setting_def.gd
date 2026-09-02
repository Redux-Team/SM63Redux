class_name SettingDef
extends RefCounted

## One setting, declared in full: how it is stored, how it is drawn, and what applying it does.
## [SettingsCatalog] holds the list of these; persistence ([Settings]) and the settings UI are
## both derived from it, so a new setting is one entry in one file rather than a storage field,
## a facade property and a hand-wired widget.
##
## Built through the static constructors and refined by chaining, e.g.
## [codeblock]
## SettingDef.slider(&"audio/music_volume", "Music", 0.0, 100.0, 75.0).percent() \
##     .on_apply(func(v: float) -> void: _set_bus_volume(&"Music", v))
## [/codeblock]


enum Type {
	BOOL,
	SLIDER,
	CHOICE,
	KEYBIND,
	## Stored and persisted, but drawn by a bespoke UI rather than a generated row.
	RAW,
}

enum Format {
	NONE,
	VALUE,
	PERCENT,
	MULTIPLIER,
	INTEGER,
	## Whole numbers, with 0 shown as "Unlimited".
	FPS,
}


var key: StringName
var label: String
var description: String
## Heading this setting sits under on the settings screen. Consecutive settings sharing one are
## drawn under a single centred header, the way the old screen grouped them.
var group: String = ""
var type: Type
var default_value: Variant

var minimum: float = 0.0
var maximum: float = 1.0
var step: float = 0.0
var format: Format = Format.NONE

## Display name -> stored value. Dictionaries keep insertion order, so this doubles as the
## option ordering. Empty when [member choices_provider] fills it in at runtime instead.
var choices: Dictionary[String, Variant] = {}
## Returns the choice map for options that only exist at runtime (audio output devices).
var choices_provider: Callable

## Run whenever the value changes, and once for every setting at startup.
var applier: Callable
## Hides the row when it returns false (settings that only apply to some devices).
var available: Callable
## Writes the value only once the slider is let go. For settings whose applier is expensive or
## visually disruptive to run on every intermediate value.
var apply_on_release: bool = false


static func boolean(setting_key: StringName, setting_label: String, default: bool) -> SettingDef:
	var def: SettingDef = SettingDef.new()
	def.key = setting_key
	def.label = setting_label
	def.type = Type.BOOL
	def.default_value = default
	return def


static func slider(setting_key: StringName, setting_label: String, low: float, high: float, default: float) -> SettingDef:
	var def: SettingDef = SettingDef.new()
	def.key = setting_key
	def.label = setting_label
	def.type = Type.SLIDER
	def.default_value = default
	def.minimum = low
	def.maximum = high
	def.format = Format.VALUE
	return def


static func choice(setting_key: StringName, setting_label: String, options: Dictionary[String, Variant], default: Variant) -> SettingDef:
	var def: SettingDef = SettingDef.new()
	def.key = setting_key
	def.label = setting_label
	def.type = Type.CHOICE
	def.default_value = default
	def.choices = options
	return def


static func keybind(setting_key: StringName, setting_label: String) -> SettingDef:
	var def: SettingDef = SettingDef.new()
	def.key = setting_key
	def.label = setting_label
	def.type = Type.KEYBIND
	def.default_value = PackedStringArray()
	return def


static func raw(setting_key: StringName, default: Variant) -> SettingDef:
	var def: SettingDef = SettingDef.new()
	def.key = setting_key
	def.type = Type.RAW
	def.default_value = default
	return def


func hint(text: String) -> SettingDef:
	description = text
	return self


func in_group(name: String) -> SettingDef:
	group = name
	return self


func stepped(value: float) -> SettingDef:
	step = value
	return self


func percent() -> SettingDef:
	format = Format.PERCENT
	step = 1.0
	return self


func multiplier() -> SettingDef:
	format = Format.MULTIPLIER
	return self


func integer() -> SettingDef:
	format = Format.INTEGER
	step = 1.0
	return self


func fps() -> SettingDef:
	format = Format.FPS
	return self


func on_apply(callable: Callable) -> SettingDef:
	applier = callable
	return self


func deferred() -> SettingDef:
	apply_on_release = true
	return self


func available_when(callable: Callable) -> SettingDef:
	available = callable
	return self


func provide_choices(callable: Callable) -> SettingDef:
	choices_provider = callable
	return self


## Leading path element of the key, e.g. &"audio" for &"audio/music_volume". Doubles as the
## config file section and the settings screen tab.
func get_section() -> StringName:
	return StringName(String(key).get_slice("/", 0))


## Trailing path element of the key, used as the config file entry name.
func get_entry() -> String:
	return String(key).get_slice("/", 1)


func get_choices() -> Dictionary[String, Variant]:
	if choices_provider.is_valid():
		return choices_provider.call()
	return choices


func is_available() -> bool:
	if available.is_valid():
		return available.call()
	return true


## Forces [param value] into something this setting can actually hold, falling back to the
## default when it cannot. Every read from disk goes through here, so an outdated or hand-edited
## config degrades one entry at a time instead of being thrown away wholesale.
func coerce(value: Variant) -> Variant:
	match type:
		Type.BOOL:
			return value if value is bool else default_value
		Type.SLIDER:
			if value is not float and value is not int:
				return default_value
			var number: float = float(value)
			if step > 0.0:
				number = snappedf(number, step)
			return clampf(number, minimum, maximum)
		Type.CHOICE:
			return value if get_choices().values().has(value) else default_value
		Type.KEYBIND:
			return PackedStringArray(value) if value is PackedStringArray or value is Array else default_value
	return value


## Human-readable form of a slider value, per [member format].
func format_value(value: float) -> String:
	match format:
		Format.PERCENT:
			return "%d%%" % roundi(value)
		Format.MULTIPLIER:
			return "%.2fx" % value
		Format.INTEGER:
			return "%d" % roundi(value)
		Format.FPS:
			return "Unlimited" if roundi(value) <= 0 else "%d FPS" % roundi(value)
		Format.VALUE:
			return "%.1f" % value
	return ""
