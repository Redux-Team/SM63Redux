class_name Settings

## Player-facing configuration: the values behind [SettingsCatalog]'s declarations, persisted to
## a plain [ConfigFile] at [constant CONFIG_PATH]. Read and written statically, e.g.
## [code]Settings.get_float(&"audio/music_volume")[/code].
##
## An INI file rather than a serialized [Resource]: unknown entries are ignored, missing ones fall
## back to the declared default, and a wrong-typed one is rejected by [method SettingDef.coerce],
## so a config written by an older build degrades per entry instead of needing to be validated
## (and discarded) as a whole.


const CONFIG_PATH: String = "user://settings.cfg"
## Writes are coalesced this long so dragging a slider costs one file write, not one per pixel.
const SAVE_DEBOUNCE: float = 0.35


## Signal carrier. Connect through it: [code]Settings.bus.changed.connect(callable)[/code].
static var bus: SettingsBus = SettingsBus.new()

static var _defs: Dictionary[StringName, SettingDef] = {}
static var _order: Array[SettingDef] = []
static var _values: Dictionary[StringName, Variant] = {}
static var _config: ConfigFile
static var _loaded: bool = false
static var _save_queued: bool = false


## Loads the catalog and the stored values, then applies everything. Called once from
## [Singleton], so nothing touches the filesystem at class-load time.
static func initialize() -> void:
	_ensure_loaded()
	apply_all()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	
	for def: SettingDef in SettingsCatalog.build():
		_defs.set(def.key, def)
		_order.append(def)
	
	_config = ConfigFile.new()
	_config.load(CONFIG_PATH)
	
	for def: SettingDef in _order:
		var stored: Variant = _config.get_value(def.get_section(), def.get_entry(), def.default_value)
		_values.set(def.key, def.coerce(stored))


## Runs every setting's applier. Used at startup and after a bulk change such as a section reset.
static func apply_all() -> void:
	_ensure_loaded()
	for def: SettingDef in _order:
		_apply(def)


static func has(key: StringName) -> bool:
	_ensure_loaded()
	return _defs.has(key)


static func get_def(key: StringName) -> SettingDef:
	_ensure_loaded()
	return _defs.get(key)


## Every declared setting, in catalog order.
static func get_defs() -> Array[SettingDef]:
	_ensure_loaded()
	return _order


## The declared settings in [param section], in catalog order, minus any that are unavailable
## on this platform.
static func get_section_defs(section: StringName) -> Array[SettingDef]:
	_ensure_loaded()
	var result: Array[SettingDef] = []
	for def: SettingDef in _order:
		if def.get_section() == section and def.is_available():
			result.append(def)
	return result


## Section ids in catalog order, skipping sections whose settings are all unavailable.
static func get_sections() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	for def: SettingDef in _order:
		var section: StringName = def.get_section()
		if not result.has(section) and def.is_available():
			result.append(section)
	return result


static func get_value(key: StringName) -> Variant:
	_ensure_loaded()
	if not _defs.has(key):
		push_warning("Settings: unknown key '%s'" % key)
		return null
	return _values.get(key)


static func get_bool(key: StringName) -> bool:
	return bool(get_value(key))


static func get_float(key: StringName) -> float:
	return float(get_value(key))


static func get_int(key: StringName) -> int:
	return int(get_value(key))


static func get_string(key: StringName) -> String:
	return String(get_value(key))


## Stores [param value], applies it and schedules a save. Values that survive
## [method SettingDef.coerce] unchanged are dropped, so re-setting the current value costs
## nothing and cannot loop a UI row back through its own signal.
static func set_value(key: StringName, value: Variant) -> void:
	_ensure_loaded()
	var def: SettingDef = _defs.get(key)
	if not def:
		push_warning("Settings: unknown key '%s'" % key)
		return
	
	var coerced: Variant = def.coerce(value)
	if _values.get(key) == coerced:
		return
	
	_values.set(key, coerced)
	_write(def, coerced)
	_apply(def)
	bus.changed.emit(key, coerced)
	_queue_save()


## Restores one setting to its declared default.
static func reset(key: StringName) -> void:
	_ensure_loaded()
	var def: SettingDef = _defs.get(key)
	if def:
		set_value(key, def.default_value)


## Restores every setting in [param section] to its declared default.
static func reset_section(section: StringName) -> void:
	for def: SettingDef in get_section_defs(section):
		reset(def.key)


## Restores every declared setting to its default, including ones no section currently shows.
static func reset_all() -> void:
	_ensure_loaded()
	for def: SettingDef in _order:
		reset(def.key)


## Only values that differ from the default are stored. Keeping the file to what the player
## actually changed means a default revised in a later build still reaches everyone who never
## touched that setting.
static func _write(def: SettingDef, value: Variant) -> void:
	var section: String = def.get_section()
	var entry: String = def.get_entry()
	
	if value == def.default_value:
		if _config.has_section_key(section, entry):
			_config.erase_section_key(section, entry)
		return
	
	_config.set_value(section, entry, value)


static func _apply(def: SettingDef) -> void:
	if def.applier.is_valid():
		def.applier.call(_values.get(def.key))


static func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		flush()
		return
	
	# Unaffected by the debug time scale, which can be zero.
	await tree.create_timer(SAVE_DEBOUNCE, true, false, true).timeout
	flush()


## Writes pending changes out immediately. Called on quit so a change made in the last third of
## a second is not lost.
static func flush() -> void:
	_save_queued = false
	if _config:
		_config.save(CONFIG_PATH)
