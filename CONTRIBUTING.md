# Contributing to Super Mario 63 Redux

## Setting up
The project is developed with Godot 4.7. Clone the repository and open `project.godot` in the editor.

Before your first commit, I highly recommend enabling the repo's git hooks so that the styleguide is automatically checked locally:
```sh
git config core.hooksPath .githooks
```
The pre-commit hook runs the style test whenever a commit includes `.gd` or `.gdshader` files, and blocks the commit if it fails, listing every offending line. If `godot` isn't on your `PATH`, point the hook at your Godot binary with the `GODOT` environment variable.

## Styleguide
Rules marked with an asterisk `*` are checked automatically by the engine, style test, pre-commit, and CI. The rest is checked when reviewed.

Rules marked with an exclamation point `!` are mostly enforced as well, but exceptions are sometimes necessary and accepted.

### GDScript
- \* Static types everywhere, including loop variables (`for i: int in range(3):`). Untyped and inferred declarations are automatic errors in-engine.
- \* Never use `:=`; always write the type out: `var speed: float = 0.0`.
- \* Nodes and resources should always use `@export` variables. Do not use `@onready`, `$Node` or `%Node`. If deferred values are necessary, then they can be assigned via `_init()` or `_ready()`
- ! Signal emission should be done via `<signal>.emit()` instead of `emit_signal()`.
- \* Use `and`, `or` and `not`, never `&&`, `||` or `!`.
- \* One statement per line: no `;`, and no body on the same line as `if x:`, `for ...:`, `else:` or a `func` signature. Single-line lambdas and ternaries are fine.
- \* Use double quotes, unless single quotes avoid escaping a `"`.
- \* Naming: `snake_case` for files, functions, variables, parameters and signals; `CONSTANT_CASE` for constants and enum members; `PascalCase` for `class_name`, inner classes and enums. A constant holding a `preload()`ed class may be `PascalCase`.
- \* A script with a `class_name` is named after it: `class_name DiveState` lives in `dive_state.gd` (a leading `_` for helpers is allowed).
- \* Members follow Godot's order: `@tool`/`@icon`, `class_name`, `extends`, signals, enums, constants, static variables, `@export` variables, variables, `_static_init()`, static methods, built-in virtual methods (`_init`, `_enter_tree`, `_ready`, `_process`, `_physics_process`, then the rest), overridden methods, methods, inner classes. Public comes before private within each group.
- \* Use the proper string-type convention. So, Strings would use `""`, StringNames would use `&""`, and NodePath would use `^""`.
- Index arrays & dictionaries with `[]`, since it maintains type-safety. Unfortunately `.get()`/`.set()` go through `Variant`, which is not statically-checked by the engine. Use `Dictionary.get(key, default)` only when the key may be missing.
- Try to avoid unnecessary comments if possible. Code should explain itself through naming and structure for the most part.
- Most importantly: always try to prefer the clean and maintainable solution wherever it makes sense to, even if it bends a convention or "optimal" solution.

### Formatting
- \* Indent with tabs.
- \* Blank lines inside a block should carry the indentation of the line behind them. Only blank lines at the top level are truly empty.
- \* Two blank lines around functions and classes, including inner classes and their methods. Use one (properly tablulated) blank line within a block to separate logic a bit more.
- \* One space around operators and after commas, none inside `()` or `[]`, and no extra spaces to align things. Single-line dictionaries get a space inside their braces: `{ "key": value }`; an empty one is `{}`.
- \* Multi-line arrays, dictionaries and enums end with a trailing comma, and single-line lists don't. Enum constants go on their own lines.
- \* Write floats with both digits (`0.5`, `13.0`), hexadecimal in lowercase (`0xff`), and large numbers with `_` separators (`1_000_000`).
- \* Continuation lines (inside `( )`, multi-line indexes, and after a `\`) take **two** indent levels; the contents of array, dictionary and enum literals take **one**. The closing bracket returns to the indent of the line that opened it.
- \* No parentheses around a whole condition, right-hand side or `return` value unless the expression is wrapped over several lines.
- \* No trailing whitespace & have exactly one newline at the end of the file.
- \* Lines are at most 100 characters wide, counting a tab as 4. Aim for 80 where it reads naturally, but don't wrap a line just to get under 80. These 2 numbers are the 2 vertical lines seen in the godot script editor.
- A backslash `\` should be used to break a line that exceeds the character limit, normally this happens in assignment expresions, to which I'd recommend placing it after the `=`.
- Shaders are checked for tabs, blank lines, whitespace, line endings and width; the other formatting rules mainly just apply to GDScript.
- Anything not mentioned here should follow Godot's established convention: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Only wrap a line when it would go past 100, and break it wherever it flows and reads best. For a long assignment, breaking right after the `=` often reads well; otherwise use bracket blocks: the opening bracket ends the line, each item goes on its own line with a trailing comma, and the closing bracket goes back on its own line. Long conditions and expressions are wrapped in parentheses with the operator leading each line:
```gdscript
var gravity_component: GravityComponent = player.get_component(GravityComponent)

player.velocity.x = \
		Motion.damp(forward, entry_speed, entry_halflife, delta) * player.get_facing()

_add_menu_item(
		"Move Selection Here",
		_move_selection_to.bind(category, group),
		ld_object_handler.get_selection_bounds().get_center(),
)

if (
		player.is_on_wall() or player.is_on_ceiling()
		or (player.caps.is_running(&"Wing") and player.velocity.y > glide_speed_limit)
):
	pass

var speeds: Dictionary[StringName, float] = {
	&"walk": 120.0,
	&"run": 240.0,
}

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_drop_speed: float = 307.5
```

## Running unit tests
To run all of the unit tests, as CI does:
```sh
godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://dev/unit_tests/_cli.gd -- --verbose
```
Add `--filter <path>` to only run tests whose path contains `<path>`, for example `--filter code_follows_styleguide`.

The fast `@tool` tests can also be run from the editor with the **Run tests** button on `dev/unit_tests/_unit_tester.tres`, and they run automatically when a debug build starts.

## Writing tests
I recommend writing tests as much as possible honestly, especially for utility & helper classes.
- All unit tests are found in `dev/unit_tests/`. Each test is a script with a `static func run_test() -> void` that uses `assert()`. It's also allowed to `await` if needed.
- The convention for naming a unit test should typically just be named after what it checks, such as `uids_and_paths_are_valid.gd` or `level_files_save_and_load.gd`. This
makes it easier to tell what the unit tests are at a glance.
- Files and folders starting with `_` are helpers and are not treated as tests.
- Mark a test `@tool` only if it is fast, synchronous and doesn't need the scene tree. Everything else only runs from the command line and in CI.
- Gameplay tests use `TestStage` (`dev/unit_tests/_test_stage.gd`) to spawn a level with the player and step it frame by frame with simulated input.
- If the code under test is *expected* to log an error, then explicitly declare that first with `UnitTester.expect_error("part of the message")`, otherwise the error fails the test.

### Other
- Keep commit messages to a short & concise title, such as `Fix hanging loading screens`.
- Pull requests will 99% of the time require CI to pass and conflicts resolved before they will be merged.

