const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const HEADER_ANNOTATIONS: String = "^@(tool|icon|static_unload|abstract)\\b"
const ANNOTATIONS: String = "^(@\\w+(\\((?:[^()]|\\([^()]*\\))*\\))?\\s*)*"
const VIRTUAL_ORDER: PackedStringArray = [
	"_init",
	"_enter_tree",
	"_ready",
	"_process",
	"_physics_process",
]
const SECTIONS: PackedStringArray = [
	"@tool and @icon",
	"class_name",
	"extends",
	"signals",
	"enums",
	"constants",
	"static variables",
	"@export variables",
	"variables",
	"@onready variables",
	"_static_init()",
	"static methods",
	"built-in virtual methods",
	"overridden methods",
	"methods",
	"inner classes",
]


static func run_test() -> void:
	for path: String in Files.find(["gd"], Files.LINT_IGNORED):
		var script: Script = load(path) as Script
		if script == null:
			continue
		
		var virtuals: Dictionary[String, bool] = _get_virtuals(script)
		var inherited: Dictionary[String, bool] = _get_inherited(script)
		var source: SourceFile = SourceFile.new(path)
		var highest: int = -1
		var highest_label: String = ""
		var annotations: String = ""
		for i: int in source.lines.size():
			if not source.is_top_level(i) or source.code[i].strip_edges().is_empty():
				continue
			
			var statement: String = annotations + source.get_statement(i)
			var member: String = \
					RegEx.create_from_string(ANNOTATIONS).sub(statement, "").strip_edges()
			if member.is_empty() and not RegEx.create_from_string(
					HEADER_ANNOTATIONS
			).search(statement):
				annotations = statement + " "
				continue
			
			annotations = ""
			
			var rank: int = _rank(statement, member, virtuals, inherited)
			if rank < 0:
				continue
			
			var label: String = _label(rank, member)
			if rank < highest:
				UnitTester.fail(path, i + 1, "%s must come before %s" % [label, highest_label])
			elif rank > highest:
				highest = rank
				highest_label = label


static func _rank(
		statement: String,
		member: String,
		virtuals: Dictionary[String, bool],
		inherited: Dictionary[String, bool],
) -> int:
	if member.is_empty():
		return _section("@tool and @icon")
	if member.begins_with("class_name"):
		return _section("class_name")
	if member.begins_with("extends"):
		return _section("extends")
	if member.begins_with("signal"):
		return _section("signals")
	if member.begins_with("enum"):
		return _section("enums")
	if member.begins_with("const"):
		return _section("constants")
	if member.begins_with("class "):
		return _section("inner classes")
	
	var variable: RegExMatch = \
			RegEx.create_from_string("^(static\\s+)?var\\s+(\\w+)").search(member)
	if variable:
		var privacy: int = 1 if variable.get_string(2).begins_with("_") else 0
		if not variable.get_string(1).is_empty():
			return _section("static variables") + privacy
		if "@onready" in statement:
			return _section("@onready variables") + privacy
		if "@export" in statement:
			return _section("@export variables")
		return _section("variables") + privacy
	
	var function: RegExMatch = \
			RegEx.create_from_string("^(static\\s+)?func\\s+(\\w+)").search(member)
	if function == null:
		return -1
	
	var name: String = function.get_string(2)
	var privacy: int = 1 if name.begins_with("_") else 0
	if not function.get_string(1).is_empty():
		if name == "_static_init":
			return _section("_static_init()")
		return _section("static methods") + privacy
	if virtuals.has(name):
		var position: int = VIRTUAL_ORDER.find(name)
		return _section("built-in virtual methods") + (
				position if position >= 0 else VIRTUAL_ORDER.size()
		)
	if inherited.has(name):
		return _section("overridden methods")
	return _section("methods") + privacy


static func _label(rank: int, member: String) -> String:
	var name: RegExMatch = RegEx.create_from_string(
			"^(?:static\\s+)?(?:var|func|signal|const|enum|class)\\s+(\\w+)"
	).search(member)
	var section: String = SECTIONS[rank / 10]
	var private: bool = rank % 10 == 1 and section in [
			"static variables",
			"variables",
			"@onready variables",
			"static methods",
			"methods",
	]
	return "%s%s%s" % [
		"private " if private else "",
		section,
		" (%s)" % name.get_string(1) if name else "",
	]


static func _section(section: String) -> int:
	return SECTIONS.find(section) * 10


static func _get_virtuals(script: Script) -> Dictionary[String, bool]:
	var virtuals: Dictionary[String, bool] = {}
	var parent: StringName = script.get_instance_base_type()
	while not parent.is_empty():
		for method: Dictionary in ClassDB.class_get_method_list(parent, true):
			if method["flags"] & METHOD_FLAG_VIRTUAL:
				virtuals[method["name"]] = true
		parent = ClassDB.get_parent_class(parent)
	return virtuals


static func _get_inherited(script: Script) -> Dictionary[String, bool]:
	var inherited: Dictionary[String, bool] = {}
	var base: Script = script.get_base_script()
	while base != null:
		for method: Dictionary in base.get_script_method_list():
			inherited[method["name"]] = true
		base = base.get_base_script()
	return inherited
