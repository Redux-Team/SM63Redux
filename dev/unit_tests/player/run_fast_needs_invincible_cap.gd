static func run_test() -> void:
	var run: Array[StringName] = await _run_animations(&"")
	assert(run.has(&"run_loop"))
	assert(not run.has(&"run_fast"))
	
	var invincible: Array[StringName] = await _run_animations(&"Invincible")
	assert(invincible.has(&"run_loop"))
	assert(invincible.has(&"run_fast"))
	assert(invincible.find(&"run_loop") < invincible.find(&"run_fast"))
	
	var metal: Array[StringName] = await _run_animations(&"Metal")
	assert(not metal.has(&"run_loop"))
	assert(not metal.has(&"run_fast"))


static func _run_animations(cap: StringName) -> Array[StringName]:
	var stage: TestStage = TestStage.create()
	await stage.start()
	var player: Player = stage.player
	if not cap.is_empty():
		stage.give_cap(cap)
	stage.hold(&"move_right")
	var animations: Array[StringName] = []
	for frame: int in 180:
		await stage.step()
		if not animations.has(player.sprite.current_animation):
			animations.append(player.sprite.current_animation)
	
	await stage.finish()
	return animations
