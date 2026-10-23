const PLATFORM_TOP: float = TestStage.FLOOR_Y - 60.0


static func run_test() -> void:
	var solid: float = await _land_from_above(PolygonCollision.CollisionMode.SOLID)
	var semisolid: float = await _land_from_above(PolygonCollision.CollisionMode.SEMISOLID)
	assert(solid < TestStage.FLOOR_Y - 30.0)
	assert(absf(semisolid - solid) < 0.5)
	
	var stage: TestStage = TestStage.create()
	_add_platform(stage, PolygonCollision.CollisionMode.SEMISOLID)
	await stage.start(60)
	var floor_height: float = stage.player.global_position.y
	assert(floor_height > PLATFORM_TOP)
	await stage.tap(&"jump", 40)
	assert(await stage.step_until(func() -> bool: return stage.player.velocity.y > 0.0, 120))
	assert(await stage.step_until_state(&"Idle", 120))
	assert(absf(stage.player.global_position.y - solid) < 0.5)
	await stage.finish()
	
	var ghost: float = await _land_from_above(PolygonCollision.CollisionMode.NONE)
	assert(absf(ghost - floor_height) < 0.5)


static func _land_from_above(mode: PolygonCollision.CollisionMode) -> float:
	var stage: TestStage = TestStage.create(true, true, Vector2(0.0, -200.0))
	_add_platform(stage, mode)
	await stage.start(90)
	assert(stage.get_state() == &"Idle")
	var height: float = stage.player.global_position.y
	await stage.finish()
	return height


static func _add_platform(stage: TestStage, mode: PolygonCollision.CollisionMode) -> void:
	var platform: ObjectData = \
			stage.add_polygon(&"terrain_grass", Rect2(-200.0, PLATFORM_TOP, 400.0, 10.0))
	platform.values[&"collision_mode"] = mode
