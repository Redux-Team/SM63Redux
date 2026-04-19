class_name SFX
extends Resource


enum TerrainType {
	GENERIC,
	GRASS,
	SAND,
	SNOW,
	CLOUD,
}


const UI_NEXT: AudioStream = preload("uid://c457x4e2iw7b")
const UI_BACK: AudioStream = preload("uid://dv2aeiyho5qtn")
const UI_CONFIRM: AudioStream = preload("uid://cg8o8vgknq1li")
const UI_START: AudioStream = preload("uid://dmop45sygbxda")

const LD_BACK: AudioStream = preload("uid://dje63yjntwtic")
const LD_CLOSE: AudioStream = preload("uid://ba7fbbaan7823")
const LD_CONFIRM: AudioStream = preload("uid://dyapufoemwyie")
const LD_DENY: AudioStream = preload("uid://bjujqv87d3mx0")
const LD_ERROR: AudioStream = preload("uid://7fdllxb8tiqr")
const LD_OPEN: AudioStream = preload("uid://b41jeumeks5wp")
const LD_SELECT: AudioStream = preload("uid://b1fnunf32dpve")

#const UI_WINDOW_OPEN: AudioStream


static func play(source: Variant, bus: StringName = &"SFX") -> void:
	if source is SFXBank:
		(source as SFXBank).play_sfx(bus)
	elif source is AudioStream:
		_play_stream(source, bus)


static func play_at(source: Variant, at: Variant, bus: StringName = &"Master") -> void:
	if source is SFXBank:
		(source as SFXBank).play_sfx_at(at, bus)
	elif source is AudioStream:
		_play_stream_at(source, at, bus)


static func stop_group(group: StringName) -> void:
	for bank: SFXBank in SFXBank.all_banks:
		if bank.is_in_group(group):
			bank.stop_all()


static func _play_stream(stream: AudioStream, bus: StringName) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.finished.connect(player.queue_free)
	Singleton.add_child(player)
	player.play()


static func _play_stream_at(stream: AudioStream, at: Variant, bus: StringName) -> void:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = bus
	player.finished.connect(player.queue_free)
	if at is Node2D:
		(at as Node2D).add_child(player)
	else:
		Singleton.add_child(player)
		player.global_position = at as Vector2
	player.play()
