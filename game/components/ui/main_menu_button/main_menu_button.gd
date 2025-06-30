@tool
class_name MainMenuButton
extends Control

enum ButtonDesign {
	STORY,
	LEVEL_DESIGNER,
	EXTRAS,
	SETTINGS,
	LOCK
}

@export var top_icon: ButtonDesign
@export var content: ButtonDesign
@export var title: ButtonDesign
@export var disabled: bool = false
@export_multiline var description: String = ""

@export_group("Frame")
@export_range(-1, 1) var hue: float = 0.0:
	set(h):
		if frame_texture:
			frame_texture.material.set_shader_parameter(&"hue_shift", h)
		hue = h
@export_range(0, 2) var saturation: float = 1.0:
	set(s):
		if frame_texture:
			frame_texture.material.set_shader_parameter(&"saturation_scale", s)
		saturation = s
@export_range(0, 2) var value: float = 1.0:
	set(v):
		if frame_texture:
			frame_texture.material.set_shader_parameter(&"value_scale", value)
		value = v

@onready var frame_texture: TextureRect = $FrameTexture
@onready var content_texture: TextureRect = $ContentTexture
@onready var title_texture: TextureRect = $TitleTexture
@onready var top_icon_texture: TextureRect = $TopIconTexture


func _ready() -> void:
	_assign_atlas_textures()
	
	frame_texture.material.set_shader_parameter(&"hue_shift", hue)
	frame_texture.material.set_shader_parameter(&"saturation_scale", saturation)
	frame_texture.material.set_shader_parameter(&"value_scale", value)
	
	if disabled:
		modulate.v = 0.4


func _process(_delta: float) -> void:
	frame_texture.material.set_shader_parameter(&"modulate_color", modulate)


func _assign_atlas_textures() -> void:
	var content_texture_atlas: AtlasTexture = content_texture.texture.duplicate()
	content_texture_atlas.region.position.y = content_texture_atlas.region.size.y * content
	content_texture.texture = content_texture_atlas
	
	var title_texture_atlas: AtlasTexture = title_texture.texture.duplicate()
	title_texture_atlas.region.position.y = title_texture_atlas.region.size.y * title
	title_texture.texture = title_texture_atlas
	
	var top_icon_texture_atlas: AtlasTexture = top_icon_texture.texture.duplicate()
	top_icon_texture_atlas.region.position.y = top_icon_texture_atlas.region.size.y * top_icon
	top_icon_texture.texture = top_icon_texture_atlas
