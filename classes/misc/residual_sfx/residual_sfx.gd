class_name ResidualSFX
extends AudioStreamPlayer2D
# A standalone sound player that self-destructs when the clip ends.
# Useful for things that need to play a sound as they're destroyed
# (which would destroy any sound nodes contained inside the object).


func _ready():
	# Set self up to self-destruct once the sound is finished.
	# warning-ignore:return_value_discarded
	connect("finished", self, "_on_ResidualSFX_finished")
	play()


func _on_ResidualSFX_finished():
	queue_free()


func _init(sound: AudioStream, pos: Vector2):
	position = pos
	stream = sound


# Takes an existing AudioStreamPlayer(2D) and makes it act like a ResidualSFX
# (outlive its parent, optionally destroy on finish).
static func new_from_existing (
	sfx: Node,
	scene_root: Node,
	destroy_on_finished = true
):
	# VALIDATE: Is the passed node an audio source?
	assert(
		sfx is AudioStreamPlayer or sfx is AudioStreamPlayer2D \
			or sfx is AudioStreamPlayer3D, # just for completeness
		"Attempted to create a residual sound from a non-sound node."
	)
	# VALIDATE: Is the passed audio source either 2D or positionless?
	if sfx is AudioStreamPlayer3D:
		push_error("""Created ResidualSFX from a 3D audio source.
			The codebase is not designed to handle 3D positions, so this
			audio source's position will be left undefined.""")
	
	if sfx is Node2D:
		# Reparent to scene root, while preserving global position.
		var sound_pos = sfx.global_position
		_move_node_to(sfx, scene_root)
		sfx.global_position = sound_pos
	else:
		# Reparent to the scene root.
		_move_node_to(sfx, scene_root)
	
	# Make the sfx player destroy on playback (if desired)
	if destroy_on_finished:
		sfx.connect("finished", sfx, "queue_free")
	# Lesgo
	sfx.play()

static func _move_node_to (node: Node, new_parent: Node):
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
