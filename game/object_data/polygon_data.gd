@tool
class_name PolygonData
extends GameObjectData

## Everything an editor polygon and its in-game counterpart need to look and behave the same.
## Art lives in the three style sub-resources so a level designer can swap any of them for a
## [PolygonStyleDB] preset per placed object without the two halves ever drifting apart.


enum LineMode { TOPLINE, EDGES_ONLY, NONE }
enum CollisionMode { SOLID, SEMISOLID, NONE }


const COLLISION_MODE_NAMES: PackedStringArray = ["Solid", "Semisolid", "None"]


@export var line_mode: LineMode = LineMode.TOPLINE:
	set(m):
		line_mode = m
		notify_property_list_changed()
		emit_changed()
@export var terrain_type: String
@export var base: PolygonBaseStyle:
	set(s):
		base = _rebind(base, s) as PolygonBaseStyle
@export var topline: PolygonToplineStyle:
	set(s):
		topline = _rebind(topline, s) as PolygonToplineStyle
@export var decoration: PolygonDecorationStyle:
	set(s):
		decoration = _rebind(decoration, s) as PolygonDecorationStyle

@export_group("Collision", "collision")
@export var collision_mode: CollisionMode = CollisionMode.SOLID:
	set(m):
		collision_mode = m
		notify_property_list_changed()
		emit_changed()
@export var collision_semisolid_depth: float = 24.0
@export var collision_semisolid_margin: float = 1.0

@export_group("Editor")
@export var edge_selection: bool = false


## Maps a level designer's [PolygonData.COLLISION_MODE_NAMES] pick back to a mode, falling
## back to the object's own default for the empty "Default" choice.
static func parse_collision_mode(mode_name: String, fallback: CollisionMode) -> CollisionMode:
	var index: int = COLLISION_MODE_NAMES.find(mode_name)
	return (index as CollisionMode) if index >= 0 else fallback


func get_placement_tool() -> String:
	return "polygon"


func get_select_tool() -> String:
	return "polygon_edit"


func _build_ld_object() -> LDObject:
	return LDObjectPolygon.from_data(self)


func _build_level_object() -> Node:
	return LevelObjectTerrain.from_data(self)


func _validate_property(property: Dictionary) -> void:
	var hidden: bool = false
	match property.name:
		&"topline":
			hidden = line_mode != LineMode.TOPLINE
		&"collision_semisolid_depth", &"collision_semisolid_margin":
			hidden = collision_mode != CollisionMode.SEMISOLID
	if hidden:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _rebind(old_style: Resource, new_style: Resource) -> Resource:
	if old_style and old_style.changed.is_connected(emit_changed):
		old_style.changed.disconnect(emit_changed)
	if new_style and not new_style.changed.is_connected(emit_changed):
		new_style.changed.connect(emit_changed)
	emit_changed()
	return new_style
