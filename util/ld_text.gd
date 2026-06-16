class_name LDText

## Text helpers for user-entered names (areas, scenarios, layers, stamps, ...).


## Restricts a name to safe characters - letters, digits, spaces, underscores and hyphens - and
## trims leading whitespace. Keeps names from breaking JSON or name-based references (no quotes,
## backslashes, etc.) while still allowing readable multi-word names.
static func sanitize_name(text: String) -> String:
	var result: String = ""
	for c: String in text:
		var ok: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
			or (c >= "0" and c <= "9") or c == " " or c == "_" or c == "-"
		if ok:
			result += c
	return result.lstrip(" ")


## Sanitizes a LineEdit's text in place (preserving the caret) and returns the cleaned value, so
## disallowed characters simply never appear as the user types.
static func sanitize_edit(edit: LineEdit) -> String:
	var clean: String = sanitize_name(edit.text)
	if clean != edit.text:
		var caret: int = edit.caret_column
		edit.text = clean
		edit.caret_column = mini(caret, clean.length())
	return clean
