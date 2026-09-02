class_name LevelObjectSprite
extends LevelObject

## The in-game half of a [SpriteForm]: a texture, and nothing else. Objects that want to be solid
## say so with a [CollisionTrait], which builds the body then, so the great majority of decorations
## carry no physics nodes rather than a body created and freed on every load.


@export var sprite: Sprite2D


static func from_data(form: ObjectForm) -> LevelObjectSprite:
	var sprite_form: SpriteForm = form as SpriteForm
	if not sprite_form:
		return null
	
	var instance: LevelObjectSprite = load("uid://b2vmgflcudxmr").instantiate()
	instance.sprite.texture = sprite_form.texture
	
	return instance


## A sprite asked to be solid without being told its shape covers its own texture.
func get_default_collision_shape() -> Shape2D:
	return Packer.get_texture_as_shape(sprite.texture) if sprite else null
