class_name LDPolygonOverlay
extends Node2D

## Editor-only markings for a polygon: the placement preview, the selection highlight and the
## semisolid hint. These live in their own node ordered after the surface rather than being drawn
## by the object itself, so the surface can stay byte-identical to the one the game builds instead
## of having to be pushed behind its parent - which breaks the fill's clipping, and took the
## topline shadows with it.


const PREVIEW_VALID_FILL: Color = Color(0.2, 0.5, 1.0, 0.25)
const PREVIEW_VALID_BORDER: Color = Color(0.0, 0.433, 1.0, 1.0)
const PREVIEW_INVALID_FILL: Color = Color(1.0, 0.2, 0.2, 0.25)
const PREVIEW_INVALID_BORDER: Color = Color(1.0, 0.0, 0.0, 0.8)
const PREVIEW_BORDER_WIDTH: float = 1.0
const SELECTION_BORDER_WIDTH: float = 1.5
const SEMISOLID_HINT_COLOR: Color = Color(1.0, 0.82, 0.25, 0.9)
const SEMISOLID_HINT_WIDTH: float = 3.0


@export var target: LDObjectPolygon


func _draw() -> void:
	if not target:
		return

	var points: PackedVector2Array = target.get_outer_points()
	if points.is_empty():
		return

	if target.is_preview:
		_draw_preview(points)
		return

	var state: LDObject.SelectionState = target.get_selection_state()
	if state == LDObject.SelectionState.HIDDEN:
		return

	var outline: Color
	var fill: Color

	match state:
		LDObject.SelectionState.HOVERED:
			outline = Color(1.0, 1.0, 1.0, 0.6)
			fill = Color(1.0, 1.0, 1.0, 0.1)
		LDObject.SelectionState.SELECTED:
			outline = Color.WHITE
			fill = Color(1.0, 1.0, 1.0, 0.15)

	draw_colored_polygon(points, fill)
	_draw_closed_polyline(points, outline, SELECTION_BORDER_WIDTH)
	_draw_semisolid_hint()


func _draw_preview(points: PackedVector2Array) -> void:
	var valid: bool = target.is_preview_valid()
	var fill: Color = PREVIEW_VALID_FILL if valid else PREVIEW_INVALID_FILL
	var border: Color = PREVIEW_VALID_BORDER if valid else PREVIEW_INVALID_BORDER

	if points.size() >= 3:
		if valid:
			draw_colored_polygon(points, fill)
		else:
			draw_polyline(points, fill)
	if points.size() >= 2:
		_draw_closed_polyline(points, border, PREVIEW_BORDER_WIDTH)

	for hole: PackedVector2Array in target.get_holes():
		if hole.size() >= 3:
			draw_colored_polygon(hole, Color(0.0, 0.0, 0.0, 0.4))
			_draw_closed_polyline(hole, border, PREVIEW_BORDER_WIDTH)


## Marks the edges that one-way collision will be built from, so a semisolid polygon still reads as
## one when its topline art is hidden.
func _draw_semisolid_hint() -> void:
	if target.surface.get_collision_mode() != PolygonData.CollisionMode.SEMISOLID:
		return
	for segment: PackedVector2Array in target.surface.get_topline_segments():
		if segment.size() >= 2:
			draw_polyline(segment, SEMISOLID_HINT_COLOR, SEMISOLID_HINT_WIDTH, true)


func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var count: int = points.size()
	for i: int in count:
		draw_line(points[i], points[(i + 1) % count], color, width, true)
