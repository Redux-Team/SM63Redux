class_name Playlist
extends Resource

enum Bus {
	MASTER,
	MUSIC,
	SFX_,
}

enum PlayOrder {
	## Fully random; the same sound effect can play more than once.
	RANDOM,
	## Random order, but the same sound effect cannot play twice in a row.
	RANDOM_NEW,
	## Random order, but each sound effect only plays once. Does not repeat unless [param repeat_list] is set to [code]true[/code]
	RANDOM_ONCE,
	## All sound effects play in order upon each [code]play_sfx_at()[/code] call. Does not repeat unless [param repeat_list] is set to [code]true[/code]
	SEQUENTIAL,
}

## List of possible sound effect(s) this layer can iterate through.
@export var tracklist: Array[AudioStream]
## What audio bus this layer should play its sound effect(s) to.
@export var bus: Bus:
	set(b):
		match b:
			Bus.MASTER: selected_bus = &"Master"
			Bus.MUSIC: selected_bus = &"Music"
			Bus.SFX_: selected_bus = &"SFX"
		bus = b
var selected_bus: StringName = &"Master"

## Determines the order in which sound effects are played
@export var play_order: PlayOrder = PlayOrder.RANDOM_NEW
## Allow for songs to repeat in play orders like [member PlayOrder.RANDOM_ONCE] and [member PlayOrder.SEQUENTIAL]
@export var repeat_list: bool
## How many seconds pass before the sound effect(s) play.
@export var start_delay: float = 0.0
## How many seconds should pass before the sound effect(s) can play again.
@export var repeat_delay: float = 0.0
## Whether or not playing these sound effect(s) should end
## all the other sound effects in the same AudioBus.
@export var overwrite_other: bool = false

var last_pick: int
var new_pick: int
var repeat_timer: SceneTreeTimer
# This variable is for RANDOM_ONCE and SEQUENTIAL
var sfx_pool: Array[int]

## Plays a sound effect from the list at a specific node.
func play(node: Node, index: int = -1) -> void:
	new_pick = 0
	
	if node == null or tracklist.is_empty():
		return
	
	if sfx_pool.size() == tracklist.size() and repeat_list:
		sfx_pool.clear()

	var start_timer: SceneTreeTimer = node.get_tree().create_timer(start_delay)
	if start_delay != 0:
		await start_timer.timeout

	# Repeat delay
	if not repeat_timer:
		repeat_timer = node.get_tree().create_timer(0)
	if repeat_timer.time_left > 0:
		return

	# Overwrite SFX
	if overwrite_other:
		node.get_tree().call_group(selected_bus, &"queue_free")

	# Disregard play order if the index is directly provided.
	if index >= 0 and index < tracklist.size():
		new_pick = tracklist[index].get_instance_id()
	# With play order
	else:
		match play_order:
			PlayOrder.RANDOM:
				new_pick = tracklist.pick_random().get_instance_id()
			PlayOrder.RANDOM_NEW:
				new_pick = tracklist.pick_random().get_instance_id()
				while new_pick == last_pick and tracklist.size() > 1:
					new_pick = tracklist.pick_random().get_instance_id()
			PlayOrder.RANDOM_ONCE:
				while sfx_pool.size() < tracklist.size():
					new_pick = tracklist.pick_random().get_instance_id()
					if not sfx_pool.has(new_pick) and last_pick != new_pick:
						sfx_pool.append(new_pick)
						break
			PlayOrder.SEQUENTIAL:
				if sfx_pool.size() != tracklist.size():
					new_pick = tracklist[sfx_pool.size()].get_instance_id()
					sfx_pool.append(0)
	#if new_pick:
		#SFX.play_sfx(instance_from_id(new_pick), selected_bus, node)
	last_pick = new_pick

	if repeat_delay > 0:
		repeat_timer = node.get_tree().create_timer(repeat_delay)
