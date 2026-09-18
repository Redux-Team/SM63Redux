class_name Version
extends Object
## Helper class for versioning, uses the SemVer standard (https://semver.org/).

enum VersionBranch {
	RELEASE = 3,
	BETA = 2,
	ALPHA = 1,
	DEV = 0,
	UNSET = -1,
}

## This makes iterating through version strings much easier, and it's also a good
## way to see the version priority.
const VERSION_TYPES: PackedStringArray = [
	"major_version", "minor_version", "patch_number", "branch", "branch_version"
]


var major_version: int = -1
var minor_version: int = -1
var patch_number: int = -1
var branch: VersionBranch = VersionBranch.UNSET
var branch_version: int = -1


static func from_string(version_string: String) -> Version:
	var version: Version = Version.new()
	var split_regex: RegEx = RegEx.create_from_string("[.-]")
	
	var new_version_string: String = _branch_str_to_int(version_string)
	
	var pieces: PackedStringArray = split_regex.sub(new_version_string, " ", true).split(" ")
	
	for i: int in pieces.size():
		version.set(VERSION_TYPES.get(i), pieces.get(i))
	
	return version


static func is_string_valid(version_string: String) -> bool:
	const VERSION_REGEX_STRING: String = \
		"^(?:" + \
		# x
		"\\d+|" + \
		# x.x
		"\\d+\\.\\d+|" + \
		# x.x.x
		"\\d+\\.\\d+\\.\\d+|" + \
		# x.x.x-x
		"\\d+\\.\\d+\\.\\d+-(?:dev|beta|alpha|release)|" + \
		# x.x.x-x.x
		"\\d+\\.\\d+\\.\\d+-(?:dev|beta|alpha|release)\\.\\d+" + \
		")$"
	
	var version_regex: RegEx = RegEx.create_from_string(VERSION_REGEX_STRING)
	return is_instance_valid(version_regex.search(version_string))


## Class comparison method, compares this object's version against [param version]; [br]
## [code]-1[/code] means this version is [b]older[/b] than the compared one, [br]
## [code]0[/code] means this version is [b]the same[/b] as the compared one, [br]
## [code]1[/code] means this version is [b]newer[/b] than the compared one. [br][br]
## [b]Note:[/b] Partial versions will treat its incomplete parts like a wildcard, 
## so [code]0.2[/code] will match and return [code]0[/code] with [i]any[/i] patch number or
## branch under [code]0.2.x[/code]. [br][br]
## For more explicit and semantically-safe comparisons, see [method is_older_than],
## [method is_equal_to], and [method is_newer_than]
static func compare(version_1: Version, version_2: Version) -> int:
	for version_type: String in VERSION_TYPES:
		var version_1_num: int = version_1.get(version_type)
		var version_2_num: int = version_2.get(version_type)
		
		# If the current version type is unset, we skip it.
		if version_1_num >= 0 and version_2_num >= 0:
			if version_1_num > version_2_num:
				return 1
			elif version_1_num < version_2_num:
				return -1
	
	return 0


func is_older_than(version: Version) -> bool:
	return Version.compare(self, version) == -1


func is_equal_to(version: Version) -> bool:
	return Version.compare(self, version) == 0


func is_newer_than(version: Version) -> bool:
	return Version.compare(self, version) == 1


func as_string() -> String:
	return "%s.%s.%s" % [major_version, minor_version, patch_number]


func as_string_with_branch() -> String:
	return as_string() + "-%s" % branch


func as_string_with_branch_version() -> String:
	return as_string_with_branch() + ".%s" % branch_version


func as_string_expand() -> String:
	var version_string: String = ""
	version_string += str(major_version) if major_version >= 0 else "x"
	version_string += ("." + str(minor_version)) if minor_version >= 0 else ".x"
	version_string += ("." + str(patch_number)) if minor_version >= 0 else ".x"
	version_string += ("-" + str(branch)) if branch >= 0 else ".x"
	version_string += ("." + str(branch_version)) if branch_version >= 0 else ".x"
	return version_string


func _to_string() -> String:
	var version_string: String = ""
	
	if major_version < 0:
		return version_string
	version_string += str(major_version)
	
	if minor_version < 0:
		return version_string
	version_string += "." + str(minor_version)
	
	if patch_number < 0:
		return version_string
	version_string += "." + str(patch_number)
	
	if int(branch) < 0:
		return version_string
	version_string += "-" + _branch_int_to_str(branch)
	
	if branch_version < 0:
		return version_string
	version_string += "." + str(branch_version)
	
	return version_string


static func _branch_str_to_int(version_string: String) -> String:
	return version_string \
		.replace("dev", str(VersionBranch.DEV)) \
		.replace("alpha", str(VersionBranch.ALPHA)) \
		.replace("beta", str(VersionBranch.BETA)) \
		.replace("release", str(VersionBranch.RELEASE))


static func _branch_int_to_str(branch_int: int) -> String:
	match branch_int:
		int(VersionBranch.RELEASE): return "release"
		int(VersionBranch.BETA): return "beta"
		int(VersionBranch.ALPHA): return "alpha"
		int(VersionBranch.DEV): return "dev"
	return ""
