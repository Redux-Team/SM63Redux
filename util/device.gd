class_name Device
extends Node


static func is_mobile() -> bool:
	if OS.has_feature("mobile"):
		return true
	elif OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	
	return false


static func is_desktop() -> bool:
	if OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos"):
		return true
	elif OS.has_feature("web_windows") or OS.has_feature("web_linuxbsd") or OS.has_feature("web_macos"):
		return true
	
	return false
