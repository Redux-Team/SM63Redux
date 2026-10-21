static func run_test() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_hp = 8.0
	_get_tree().root.add_child(health)
	assert(health.get_hp() == 8.0)
	
	var damages: Array[float] = []
	var deaths: Array[bool] = []
	health.damaged.connect(func(amount: float, _type: HitBox.DamageType) -> void: damages.append(amount))
	health.died.connect(func() -> void: deaths.append(true))
	
	health.damage(2.4, HitBox.DamageType.STRIKE)
	assert(health.get_hp() == 6.0)
	assert(damages == [2.4])
	health.heal(1.0)
	assert(health.get_hp() == 7.0)
	health.heal(50.0)
	assert(health.get_hp() == 8.0)
	
	health.power = 3
	assert(health.power == 0)
	health.damage(3.0, HitBox.DamageType.GENERIC)
	health.power = 3
	assert(health.power == 3)
	health.power = 7
	assert(health.power == 2)
	await health.hp_tween.finished
	assert(is_equal_approx(health.get_hp(), 6.0))
	
	health.round_to_nearest = false
	health.damage(0.5, HitBox.DamageType.GENERIC)
	assert(is_equal_approx(health.get_hp(), 5.5))
	health.set_hp(-4.0)
	assert(health.get_hp() == 0.0)
	health.set_hp(2.0)
	health.damage(5.0, HitBox.DamageType.SQUISH)
	assert(health.get_hp() == 0.0)
	assert(deaths == [true])
	health.damage(1.0, HitBox.DamageType.SQUISH)
	assert(deaths == [true])
	assert(damages.size() == 4)
	health.free()
	
	var gravity: GravityComponent = GravityComponent.new()
	gravity.strength = 10.0
	gravity.scale_factor = 2.0
	assert(gravity.get_effective_strength() == 20.0)
	gravity.set_modifier(&"water", 0.25)
	assert(gravity.get_effective_strength() == 5.0)
	gravity.clear_modifier(&"water")
	assert(gravity.get_effective_strength() == 20.0)
	assert(is_zero_approx(gravity.get_angle()))
	gravity.direction = Vector2.LEFT
	assert(is_equal_approx(gravity.get_angle(), PI / 2.0))
	gravity.direction = Vector2.UP
	assert(is_equal_approx(absf(gravity.get_angle()), PI))
	gravity.lock()
	gravity.lock()
	assert(not gravity.enabled)
	gravity.unlock()
	assert(not gravity.enabled)
	gravity.unlock()
	assert(gravity.enabled)
	gravity.unlock()
	gravity.lock()
	gravity.unlock()
	assert(gravity.enabled)
	gravity.free()
	
	var body: Body = Body.new()
	var friction: FrictionComponent = FrictionComponent.new()
	friction.entity = body
	friction.base_friction = 4.0
	friction.modifiers.set_modifier(&"ice", 0.5)
	assert(friction.get_effective() == 2.0)
	body.velocity = Vector2(1.5, 0.0)
	friction.apply()
	assert(body.velocity.x == 1.5)
	friction.apply(1.0, true)
	assert(body.velocity.x == 0.0)
	body.velocity = Vector2(-40.0, 0.0)
	friction.apply(1.0, true)
	assert(is_equal_approx(body.velocity.x, -20.0))
	friction.free()
	
	var bouncy: BouncyComponent = BouncyComponent.new()
	bouncy.entity = body
	bouncy.restitution = 0.5
	bouncy.min_velocity = 100.0
	assert(bouncy.get_effective() == 0.5)
	bouncy.apply(300.0)
	assert(body.velocity.y == -150.0)
	bouncy.apply(99.0)
	assert(body.velocity.y == 0.0)
	bouncy.free()
	
	var invulnerability: InvulnerabilityComponent = InvulnerabilityComponent.new()
	invulnerability.exceptions = [HitBox.DamageType.SQUISH]
	assert(not invulnerability.can_receive(HitBox.DamageType.STRIKE))
	assert(invulnerability.can_receive(HitBox.DamageType.SQUISH))
	invulnerability.enabled = false
	assert(invulnerability.can_receive(HitBox.DamageType.STRIKE))
	invulnerability.free()
	body.free()


static func _get_tree() -> SceneTree:
	return Engine.get_main_loop()


class Body extends Entity:
	pass
