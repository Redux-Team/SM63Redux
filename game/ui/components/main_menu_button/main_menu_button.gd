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

@onready var content_texture: TextureRect = $ContentTexture
@onready var title_texture: TextureRect = $TitleTexture
@onready var top_icon_texture: TextureRect = $TopIconTexture


func _ready() -> void:
	_assign_atlas_textures()
	
	if disabled:
		modulate.v = 0.5


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
