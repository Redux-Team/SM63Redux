@tool
extends Node

## Returns the current version of the game as a [Version].
func get_version() -> Version:
	return Version.from_string(ProjectSettings.get("application/config/version"))
