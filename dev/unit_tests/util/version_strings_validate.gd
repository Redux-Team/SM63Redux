@tool
static func run_test() -> void:
	#region String Validation
	# Verify correct strings
	assert(Version.is_string_valid("1"))
	assert(Version.is_string_valid("2198241"))
	assert(Version.is_string_valid("1.2"))
	assert(Version.is_string_valid("27.20"))
	assert(Version.is_string_valid("1.51.3"))
	assert(Version.is_string_valid("2.0.0-beta"))
	assert(Version.is_string_valid("2.0.0-alpha.1"))
	assert(Version.is_string_valid("1505.51.301-alpha.595"))
	
	# Reject incorrect strings
	assert(not Version.is_string_valid("1."))
	assert(not Version.is_string_valid(".5"))
	assert(not Version.is_string_valid(".8.8"))
	assert(not Version.is_string_valid("1.a"))
	assert(not Version.is_string_valid("1.2.3.4"))
	assert(not Version.is_string_valid("1.2.3."))
	assert(not Version.is_string_valid("1.0.0-rc1"))
	assert(not Version.is_string_valid("1.0.0-"))
	assert(not Version.is_string_valid("1..0"))
	assert(not Version.is_string_valid("v1.0.0"))
	#endregion
	
	#region Parsing Tests
	var v_parsed: Version = Version.from_string("1.2.3-beta.4")
	assert(v_parsed.major_version == 1)
	assert(v_parsed.minor_version == 2)
	assert(v_parsed.patch_number == 3)
	assert(v_parsed.branch == Version.VersionBranch.BETA)
	assert(v_parsed.branch_version == 4)
	
	var v_partial: Version = Version.from_string("3.1")
	assert(v_partial.major_version == 3)
	assert(v_partial.minor_version == 1)
	assert(v_partial.patch_number == -1)
	assert(v_partial.branch == Version.VersionBranch.UNSET)
	#endregion
	
	#region Comparison Tests
	var v_older: Version = Version.from_string("1.0.0-alpha.1")
	var v_newer: Version = Version.from_string("1.0.0-beta.1")
	assert(v_older.is_older_than(v_newer))
	assert(v_older.is_equal_to(v_older))
	assert(not v_older.is_newer_than(v_newer))
	assert(not v_older.is_equal_to(v_newer))
	assert(v_newer.is_newer_than(v_older))
	assert(v_newer.is_equal_to(v_newer))
	assert(not v_newer.is_older_than(v_older))
	assert(not v_newer.is_equal_to(v_older))
	
	var v_full: Version = Version.from_string("3.1.5-release.1")
	assert(v_partial.is_equal_to(v_full))
	#endregion
	
	#region String Reconstruction Tests
	var v_reconstruct: Version = Version.from_string("1.2.3-dev")
	assert(str(v_reconstruct) == "1.2.3-dev")
	assert(str(v_partial) == "3.1")
	assert(str(Singleton.get_version()) == ProjectSettings.get("application/config/version"))
	#endregion
