@tool
static func run_test() -> void:
	var dev: Version = Version.from_string("1.0.0-dev")
	var alpha: Version = Version.from_string("1.0.0-alpha")
	var beta: Version = Version.from_string("1.0.0-beta")
	var release: Version = Version.from_string("1.0.0-release")
	assert(dev.branch == Version.VersionBranch.DEV)
	assert(release.branch == Version.VersionBranch.RELEASE)
	assert(dev.is_older_than(alpha))
	assert(alpha.is_older_than(beta))
	assert(beta.is_older_than(release))
	assert(Version.compare(release, dev) == 1)
	assert(Version.compare(dev, release) == -1)
	assert(Version.compare(beta, beta) == 0)
	
	assert(Version.from_string("1.10.0").is_newer_than(Version.from_string("1.9.9")))
	assert(Version.from_string("2.0.0").is_newer_than(Version.from_string("1.99.99")))
	assert(Version.from_string("0.2.1").is_newer_than(Version.from_string("0.2.0-release.9")))
	assert(Version.from_string("1.0.0-beta.2").is_newer_than(Version.from_string("1.0.0-beta.1")))
	assert(Version.from_string("1.0.0-alpha.9").is_older_than(Version.from_string("1.0.0-beta.0")))
	
	var wildcard: Version = Version.from_string("0.2")
	assert(wildcard.is_equal_to(Version.from_string("0.2.7-beta.3")))
	assert(wildcard.is_equal_to(Version.from_string("0.2.0")))
	assert(wildcard.is_newer_than(Version.from_string("0.1.9")))
	assert(Version.from_string("1").is_equal_to(Version.from_string("1.5.2")))
	assert(Version.new().is_equal_to(Version.from_string("9.9.9")))
	
	var hashed: Version = Version.from_string("0.2.0-dev", "abc1234")
	assert(hashed.has_hash())
	assert(hashed.hash() == "abc1234")
	assert(not Version.from_string("0.2.0").has_hash())
	
	var full: Version = Version.from_string("4.5.6-release.7")
	assert(full.as_string() == "4.5.6")
	assert(full.as_string_with_branch() == "4.5.6-%d" % Version.VersionBranch.RELEASE)
	assert(full.as_string_with_branch_version() == "4.5.6-%d.7" % Version.VersionBranch.RELEASE)
	assert(full.as_string_expand() == "4.5.6-%d.7" % Version.VersionBranch.RELEASE)
	assert(str(full) == "4.5.6-release.7")
	assert(Version.from_string("4.5").as_string_expand() == "4.5.x-x.x")
	var partial: Version = Version.new()
	partial.major_version = 1
	partial.patch_number = 3
	assert(partial.as_string_expand() == "1.x.3-x.x")
	assert(str(Version.from_string("4.5.6-alpha")) == "4.5.6-alpha")
	assert(str(Version.from_string("4")) == "4")
	assert(str(Version.new()) == "")
	
	for text: String in ["0.2.0-dev", "1.2.3-release.4", "10.20.30-beta.40", "7.8"]:
		assert(Version.is_string_valid(text))
		assert(str(Version.from_string(text)) == text)
	
	var project_version: String = ProjectSettings.get_setting("application/config/version")
	assert(Version.is_string_valid(project_version))
