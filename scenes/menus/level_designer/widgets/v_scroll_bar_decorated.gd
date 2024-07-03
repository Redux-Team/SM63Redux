@tool
class_name VScrollBarDecorated
extends VScrollBar
## Scroll bar with a decoration icon at the center of the grabber.
##
## Please be warned that for technical reasons, the decoration's position can
## only be consistently correct if the scrollbar theme graphics have consistent
## size and padding across regular, focused, highlighted, and pressed states.

@export var decoration: Texture2D

var deco_sprite: TextureRect
var deco_tex: Texture2D
var deco_tex_highlight: Texture2D
var deco_tex_pressed: Texture2D

# Need these to get the actual displayed bar height.
@onready var _inc_height = theme.get_icon("increment", "VScrollBar").get_height()
@onready var _dec_height = theme.get_icon("decrement", "VScrollBar").get_height()
@onready var _grabber_pad = _v_margins(theme.get_stylebox("grabber", "VScrollBar"))

func _ready():
	# Read decoration textures from theme
	# Create decoration node.
	deco_sprite = TextureRect.new()
	deco_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	deco_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add it to the tree.
	add_child(deco_sprite, false, Node.INTERNAL_MODE_BACK)
	
	# Load decoration visuals from the theme.
	deco_tex = decoration
	#deco_tex = theme.get_icon("decoration", "VScrollBarDecorated")
	#deco_tex_highlight = theme.get_icon("decoration_highlight", "VScrollBarDecorated")
	#deco_tex_pressed = theme.get_icon("decoration_pressed", "VScrollBarDecorated")
	
	# Init sprite to showing one.
	deco_sprite.texture = deco_tex


func _draw():
	var cur_sprite = deco_tex # TODO: Select by mouse-over state?
	
	# Calculate height of actual background area (without inc+dec buttons or
	# the inflexible parts of the grabber).
	var bar_height = size.y
	bar_height -= _inc_height
	bar_height -= _dec_height
	bar_height -= _grabber_pad
	
	# How much the bar is stretched relative to its value range.
	var bar_stretch = bar_height / (max_value - min_value)
	
	var grabber_height = page * bar_stretch
	
	var grabber_pos = (self.value - min_value) * bar_stretch
	grabber_pos += _dec_height
	
	deco_sprite.position = Vector2(0, 
		grabber_pos - cur_sprite.get_height()/2 + grabber_height/2)


func _v_margins(stylebox: StyleBoxTexture) -> float:
	return stylebox.texture_margin_bottom + stylebox.texture_margin_top
