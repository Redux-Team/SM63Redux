# Contributing to Super Mario 63 Redux

## Setting up
The project is developed with Godot 4.7. Clone the repository and open `project.godot` in the editor.


## Running the tests
To run all of the unit tests, as CI does:
```sh
godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://dev/unit_tests/_cli.gd -- --verbose
```
Add `--filter <path>` to only run tests whose path contains `<path>`, for example `--filter code_follows_styleguide`.

The fast `@tool` tests can also be run from the editor with the **Run tests** button on `dev/unit_tests/_unit_tester.tres`, and they run automatically when a debug build starts.

## Writing tests
- Tests live in `dev/unit_tests/`, in any subfolder. Each test is a script with a `static func run_test() -> void` that uses `assert()`. It may `await`.
- Name a test after what it checks, as a statement, such as `uids_and_paths_are_valid.gd` or `level_files_save_and_load.gd`.
- Files and folders starting with `_` are helpers and are never run as tests.
- Mark a test `@tool` only if it is fast, synchronous and doesn't need the scene tree. Everything else only runs from the command line and in CI.
- Gameplay tests use `TestStage` (`dev/unit_tests/_stage.gd`) to spawn a level with the player and step it frame by frame with simulated input.
- If the code under test is expected to log an error, declare it first with `UnitTester.expect_error("part of the message")`, otherwise the error fails the test.

## Styleguide
Rules marked ✔ are checked automatically by the style test and CI. The rest are checked in review.

### GDScript
- ✔ Static types everywhere, including loop variables (`for i: int in range(3):`). Untyped and inferred declarations are errors in the project settings.
- ✔ Never use `:=`; write the type out: `var speed: float = 0.0`.
- ✔ Reference nodes with `@export` variables assigned in the inspector. Never use `@onready`, `$Node` or `%Node`.
- ✔ Emit signals with `<signal>.emit()`, never `emit_signal()`.
- No comments. Code should explain itself through naming and structure; put explanations in the pull request instead.
- Prefer the clean and maintainable solution, even if it bends a convention.

### Formatting (GDScript and GDShader)
- ✔ Indent with tabs.
- ✔ Blank lines inside a block carry the indentation of the line that follows them. Only blank lines at the top level are truly empty.
- ✔ Two blank lines between functions.
- ✔ No trailing whitespace, LF line endings, and exactly one newline at the end of the file.

### Project
- ✔ Commit the `.uid` file next to every script and shader. Godot generates it when the file is created in the editor.
- Keep commit messages to a short, imperative title line, such as `Fix hanging loading screens`.
- Pull requests need CI to pass before they are merged.
