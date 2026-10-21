static func run_test() -> void:
	var stage: TestStage = TestStage.create()
	stage.add_polygon(&"water", Rect2(-400.0, -100.0, 800.0, 160.0))
	await stage.start()
	assert(stage.player.is_swimming())
	assert(stage.get_state() == &"SwimIdle")
	await stage.finish()
	
	stage = TestStage.create()
	stage.add_polygon(
		&"water",
		Rect2(-400.0, -100.0, 800.0, 160.0),
		stage.add_layer(true),
	)
	await stage.start()
	assert(not stage.player.is_swimming())
	assert(stage.get_state() == &"Idle")
	await stage.finish()
	
	stage = TestStage.create()
	stage.add_polygon(&"water", Rect2(-400.0, -100.0, 800.0, 160.0))
	await stage.start()
	stage.give_cap(&"Metal")
	await stage.step(30)
	assert(stage.player.is_in_water())
	assert(not stage.player.is_swimming())
	assert(stage.get_state() == &"Idle")
	await stage.finish()
