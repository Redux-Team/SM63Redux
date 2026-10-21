@tool
static func run_test() -> void:
	var stack: ModifierStack = ModifierStack.new()
	assert(stack.product() == 1.0)
	assert(not stack.has_modifier(&"water"))
	
	stack.set_modifier(&"water", 0.5)
	stack.set_modifier(&"cap", 3.0)
	assert(stack.has_modifier(&"water"))
	assert(is_equal_approx(stack.product(), 1.5))
	
	stack.set_modifier(&"cap", 2.0)
	assert(is_equal_approx(stack.product(), 1.0))
	
	stack.set_modifier(&"boost", 4.0, 0.5)
	assert(is_equal_approx(stack.product(), 4.0))
	stack.tick(0.25)
	assert(stack.has_modifier(&"boost"))
	stack.tick(0.25)
	assert(not stack.has_modifier(&"boost"))
	assert(stack.has_modifier(&"water"))
	assert(is_equal_approx(stack.product(), 1.0))
	
	stack.set_modifier(&"boost", 4.0, 0.1)
	stack.set_modifier(&"boost", 4.0)
	stack.tick(10.0)
	assert(stack.has_modifier(&"boost"))
	
	stack.clear_modifier(&"boost")
	assert(not stack.has_modifier(&"boost"))
	stack.clear_modifier(&"missing")
	
	stack.set_modifier(&"frozen", 0.0)
	assert(stack.product() == 0.0)
	
	stack.clear()
	assert(stack.product() == 1.0)
	assert(not stack.has_modifier(&"water"))
	stack.tick(1.0)
