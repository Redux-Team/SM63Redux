class_name SFX
extends Resource

enum TerrainType {
	GENERIC,
	GRASS,
	SAND,
	SNOW,
	CLOUD
}

const UI_NEXT: AudioStream = preload("uid://c457x4e2iw7b")
const UI_BACK: AudioStream = preload("uid://dv2aeiyho5qtn")
const UI_CONFIRM: AudioStream = preload("uid://cg8o8vgknq1li")
const UI_START: AudioStream = preload("uid://dmop45sygbxda")


static func play(sfx: AudioStream) -> void:
	Singleton._play_sfx(sfx)
