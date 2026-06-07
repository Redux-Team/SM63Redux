class_name PlayerFluddHandler
extends Node

enum FluddNozzle {
	NONE,
	HOVER,
	ROCKET,
	TURBO,
	MAX
}

signal fludd_fuel_changed(fuel_amount: float)
signal fludd_power_changed(power_amount: float)
signal fludd_nozzle_changed(nozzle: FluddNozzle)

@export var nozzle_switch_sfx: AudioStream

@export var player: Player

@export var fludd_fuel: float = 100.0:
	set(ff):
		fludd_fuel = clamp(ff, 0, 100)
		fludd_fuel_changed.emit(fludd_fuel)
@export var fludd_power: float = 100.0:
	set(fp):
		fludd_power = clamp(fp, 0, 100)
		fludd_power_changed.emit(fludd_power)
@export var equipped_nozzle: FluddNozzle:
	set(en):
		equipped_nozzle = en
		fludd_nozzle_changed.emit(en)
@export var held_nozzles: Dictionary[FluddNozzle, bool] = {
	FluddNozzle.NONE: true,
	FluddNozzle.HOVER: false,
	FluddNozzle.ROCKET: false,
	FluddNozzle.TURBO: false,
}


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_COMMA):
		fludd_power -= 1.0
	elif Input.is_key_pressed(KEY_PERIOD):
		fludd_power += 1.0
	elif Input.is_action_just_pressed("crouch"):
		fludd_power = 100


func _input(event: InputEvent) -> void:
	# FluddNozzle.NONE should never be false, throw an error if it is
	assert(held_nozzles.get(FluddNozzle.NONE))
	
	
	if event.is_action_pressed(&"switch_fludd_nozzle"):
		var successful_switch: bool = switch_nozzle()
		if successful_switch:
			SFX.build()\
				.set_stream(nozzle_switch_sfx)\
				.set_db(-10)\
				.set_bus(&"Player")\
				.play()
	if event is InputEventKey:
		if event.keycode == KEY_I:
			player.get_fludd_handler().fludd_fuel = 0


func switch_nozzle() -> bool:
	var nozzle_switched: bool = false
	var t_eqipped: FluddNozzle = equipped_nozzle
	var try_nozzle: int = equipped_nozzle
	
	while not nozzle_switched:
		try_nozzle = wrapi(try_nozzle + 1, FluddNozzle.NONE, FluddNozzle.MAX)
		if held_nozzles.get(try_nozzle):
			equipped_nozzle = try_nozzle as FluddNozzle
			nozzle_switched = true
	
	if equipped_nozzle != t_eqipped:
		fludd_nozzle_changed.emit(equipped_nozzle)
		return true
	
	return false


func switch_nozzle_to(nozzle: FluddNozzle) -> void:
	equipped_nozzle = nozzle
