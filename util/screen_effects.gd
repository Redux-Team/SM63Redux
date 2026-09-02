class_name ScreenEffects

## Gate for the shaders that read the framebuffer back - the window backdrop's blur, and anything
## else reaching for [code]hint_screen_texture[/code]. Each one costs a full-screen copy, and a
## mipmap chain where it samples one, before it shades a single pixel; that copy, rather than the
## arithmetic around it, is what integrated graphics actually choke on. [constant SETTING] drops
## them as a group.
##
## An effect registers the material it wants through [method apply] and is restored from that
## registration when the setting comes back, so a node opts in with one call and the toggle
## restyles live rather than waiting for a restart:
## [codeblock]
## ScreenEffects.apply(_backdrop, _backdrop.material)
## [/codeblock]


const SETTING: StringName = &"display/screen_effects"
## Registered items, so a change can reach the ones already on screen.
const GROUP: StringName = &"screen_effects"
## Parks the registered material while the setting is off. Held on the node so it dies with the
## node, rather than in a table that would outlive whatever it was keyed to.
const META: StringName = &"screen_effect_material"


static func enabled() -> bool:
	return Settings.get_bool(SETTING)


## Gives [param item] its screen-reading [param effect], or leaves it unshaded while the setting
## is off. Registers the pairing either way, so a later toggle can find it again.
static func apply(item: CanvasItem, effect: Material) -> void:
	item.set_meta(META, effect)
	if not item.is_in_group(GROUP):
		item.add_to_group(GROUP)
	item.material = effect if enabled() else null


## Re-applies every registered item, for when the setting changes under them.
static func refresh_all() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var on: bool = enabled()
	for item: CanvasItem in tree.get_nodes_in_group(GROUP):
		item.material = item.get_meta(META) if on else null
