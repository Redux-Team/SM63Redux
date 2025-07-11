class_name InputIconMap
extends Resource

@export var map: Dictionary[InputEvent, Texture2D]


func from_event(event: InputEvent) -> Texture2D:
	for mapped_event: InputEvent in map:
		if event.is_match(mapped_event):
			return map.get(mapped_event)
	
	return null
