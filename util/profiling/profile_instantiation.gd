class_name ProfileInstantiation

const _WARMUP_SLICES: int = 5
const _SLICE_USEC: int = 20_000
const _REPS: int = 5
const _PARTICLE_AMOUNT: int = 32
const _REFERENCE: int = 249


static func run() -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	if tree == null:
		return 0.0
	
	var scene: PackedScene = _build_scene()
	
	for i: int in _WARMUP_SLICES:
		_slice(scene)
		await tree.process_frame
	
	var best: int = 0
	
	for rep: int in _REPS:
		best = maxi(best, _slice(scene))
		await tree.process_frame
	
	return 1.0 - (float(_REFERENCE) / float(maxi(best, 1)))


static func _slice(scene: PackedScene) -> int:
	var units: int = 0
	var start: int = Time.get_ticks_usec()
	
	while Time.get_ticks_usec() - start < _SLICE_USEC:
		scene.instantiate().free()
		units += 1
	
	return units


static func _build_scene() -> PackedScene:
	var root: Node2D = Node2D.new()
	var body: CharacterBody2D = CharacterBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var particles: CPUParticles2D = CPUParticles2D.new()
	
	shape.shape = RectangleShape2D.new()
	particles.amount = _PARTICLE_AMOUNT
	
	_attach(root, Sprite2D.new(), root)
	_attach(root, AnimationPlayer.new(), root)
	_attach(root, particles, root)
	_attach(root, body, root)
	_attach(body, shape, root)
	
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	
	return packed


static func _attach(parent: Node, child: Node, scene_owner: Node) -> void:
	parent.add_child(child)
	child.owner = scene_owner
