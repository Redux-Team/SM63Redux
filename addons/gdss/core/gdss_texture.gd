@tool
class_name GdssTexture
extends RefCounted

## Mipmapped filtering is deliberately absent: a sampler's filter is fixed when the shader
## compiles, so each option costs a sampler variant. Nearest and linear are the two that
## matter for panel art; mipmaps remain an import setting on the texture itself.

var texture: Texture2D
var interpolation: GDSS.Interpolation = GDSS.Interpolation.DEFAULT
var repeat: bool = false
var preserve_aspect: bool = false


static func interpolation_names() -> PackedStringArray:
	return PackedStringArray(GDSS.Interpolation.keys())


## Accepts a name ("NEAREST") or an already-resolved enum value.
static func parse_interpolation(value: Variant) -> GDSS.Interpolation:
	if value is int:
		return value as GDSS.Interpolation
	var index: int = interpolation_names().find(str(value).strip_edges().to_upper())
	return index if index != -1 else GDSS.Interpolation.DEFAULT


func is_nearest() -> bool:
	return interpolation == GDSS.Interpolation.NEAREST
