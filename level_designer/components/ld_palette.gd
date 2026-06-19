class_name LDPalette
extends RefCounted

## Bridges the in-viewport Node2D gizmos (vertices, handles, marquee, previews,
## touch ring) to the GDSS theme palette so the canvas stays coherent with the
## panels. GDSS styles Control nodes directly, but Node2D._draw() can't be themed,
## so those draw calls read the SAME @global vars from theme.tgdss through here.
## Every getter falls back to the theme's literal value if GDSS isn't loaded yet
## (e.g. in-editor preview), so drawing is always safe.


static func color(var_name: String, fallback: Color) -> Color:
	var value: Variant = GDSS.get_global_var(var_name, fallback)
	return value if value is Color else fallback


## Sky-blue brand accent — selection, active handles, highlights.
static func accent() -> Color:
	return color("accent", Color("#3da4ff"))


## Near-white handle/vertex fill.
static func vertex_fill() -> Color:
	return color("vertex_fill", Color("#f2f5f8"))


## Accent ring around a vertex/handle.
static func vertex_border() -> Color:
	return color("vertex_border", Color("#3da4ff"))


## Low-alpha neutral for gizmo rings / spokes.
static func gizmo_edge() -> Color:
	return color("gizmo_edge", Color(1, 1, 1, 0.4))


## Muted gray for disabled / invalid gizmo states.
static func gizmo_disabled() -> Color:
	return color("gizmo_disabled", Color("#7a818c"))


## Selection marquee / outline accent.
static func selection() -> Color:
	return color("selection", Color("#3da4ff"))


## Selection marquee fill (low alpha accent).
static func selection_fill() -> Color:
	return color("selection_fill", Color(0.24, 0.64, 1.0, 0.12))


## Additive / union semantic (polygon Add preview).
static func add_color() -> Color:
	return color("add", Color("#4ecb71"))


## Destructive / subtract semantic (polygon Cut preview).
static func danger() -> Color:
	return color("danger", Color("#e8554e"))
