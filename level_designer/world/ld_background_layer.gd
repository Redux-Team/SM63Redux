class_name LDBackgroundLayer
extends Resource

## One parallax layer of an LDBackground: a texture with its own parallax factor, tint, offset,
## autoscroll, tiling and edge anchor. The curated layer presets in db/Backgrounds/Layers are
## LDBackgroundLayer resources too: each carries a texture plus sensible defaults (including the
## right `anchor`), so adding/swapping a layer in the editor places it correctly.

enum Anchor { BOTTOM, TOP }


## Identifies which layer preset (db/Backgrounds/Layers) this came from, and its friendly name.
## Both are empty for hand-made layers.
@export var id: String = ""
@export var display_name: String = ""
## A scene override for the bg layer, for more **special** backgrounds
@export var scene_override: PackedScene

@export var texture: Texture2D
@export var parallax: float = 0.5
@export var modulate: Color = Color.WHITE
## When true, `modulate` is applied as a grayscale tint (the layer is desaturated, then colored)
## instead of a plain multiply, so a single color restyles the whole layer.
@export var custom_color: bool = false
@export var offset: Vector2 = Vector2.ZERO
@export var autoscroll: Vector2 = Vector2.ZERO
@export var repeat: bool = false
## Pins the layer flush to the top or bottom edge of the screen (clouds sit at the top, hills at the
## bottom). Comes from the layer preset, so swapping textures re-anchors correctly.
@export var anchor: Anchor = Anchor.BOTTOM


func serialize() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"texture": _resource_uid(texture),
		"scene_override": _resource_uid(scene_override),
		"parallax": parallax,
		"modulate": Packer.color_to_array(modulate),
		"custom_color": custom_color,
		"offset": Packer.vec2_to_array(offset),
		"autoscroll": Packer.vec2_to_array(autoscroll),
		"repeat": repeat,
		"anchor": int(anchor),
	}


static func deserialize(data: Dictionary) -> LDBackgroundLayer:
	var layer: LDBackgroundLayer = LDBackgroundLayer.new()
	layer.id = str(data.get("id", ""))
	layer.display_name = str(data.get("display_name", ""))
	layer.texture = _load_uid(str(data.get("texture", ""))) as Texture2D
	layer.scene_override = _load_uid(str(data.get("scene_override", ""))) as PackedScene
	layer.parallax = float(data.get("parallax", 0.5))
	layer.modulate = Packer.array_to_color(data.get("modulate", [1.0, 1.0, 1.0, 1.0]))
	layer.custom_color = bool(data.get("custom_color", false))
	layer.offset = Packer.array_to_vec2(data.get("offset", [0.0, 0.0]))
	layer.autoscroll = Packer.array_to_vec2(data.get("autoscroll", [0.0, 0.0]))
	layer.repeat = bool(data.get("repeat", false))
	layer.anchor = int(data.get("anchor", Anchor.BOTTOM)) as Anchor
	return layer


static func _resource_uid(res: Resource) -> String:
	if not res or res.resource_path.is_empty():
		return ""
	var uid_id: int = ResourceLoader.get_resource_uid(res.resource_path)
	if uid_id == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid_id)


static func _load_uid(uid: String) -> Resource:
	if uid.is_empty() or not ResourceLoader.exists(uid):
		return null
	return load(uid)
