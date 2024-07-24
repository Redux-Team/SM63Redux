extends FileDialog

func _on_SaveDialog_file_selected(path):
	var serializer = JSONSerializer.new()
	
	var level_json = serializer.generate_level_json(get_node("/root/Main"),
		get_node("/root/Main/Template"))
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(level_json)
	file.close()
