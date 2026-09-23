extends SceneTree

# Slimerot export verification must run in an empty scratch project, so missing
# packed resources cannot silently resolve from the source checkout.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	if "--slimerot-export-audit" not in OS.get_cmdline_user_args():
		push_error("Slimerot export audit requires --slimerot-export-audit.")
		quit(1)
		return
	if root.get_node_or_null("SaveManager") != null:
		push_error("Run the Slimerot export audit in an empty scratch project without gameplay autoloads.")
		quit(1)
		return
	var pack_path := ""
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--slimerot-export-pack="):
			pack_path = argument.trim_prefix("--slimerot-export-pack=")
		elif argument.begins_with("--slimerot-export-audit-output="):
			output_path = argument.trim_prefix("--slimerot-export-audit-output=")
	if pack_path.is_empty() or not FileAccess.file_exists(pack_path):
		push_error("Slimerot export audit requires an existing --slimerot-export-pack=<absolute PCK path>.")
		quit(1)
		return
	# An empty project.godot is allowed; no source assets/scripts may mask omissions.
	if DirAccess.dir_exists_absolute("res://scripts") or DirAccess.dir_exists_absolute("res://assets"):
		push_error("Slimerot export audit scratch project contains source scripts/assets.")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(pack_path):
		push_error("Slimerot export audit could not mount the PCK.")
		quit(1)
		return
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	for excluded in ["dev", "tools", "tests", "docs"]:
		_check(not files.any(func(path: String) -> bool: return path.begins_with("res://" + excluded + "/")), "export excludes " + excluded)
	for manager in ["GameState", "SlimeDatabase", "SkillTreeManager", "InventoryManager", "WorldManager", "CombatManager", "RollManager", "SaveManager"]:
		_check(ResourceLoader.exists("res://scripts/managers/Slimerot" + manager + ".gd"), "packed " + manager)
	_check(ResourceLoader.exists("res://scripts/presentation/SlimerotCombatFeedback.gd"), "packed central combat feedback")
	for scene in ["Bedroom", "Backyard", "ItalianVillage", "CursedForest", "Sahara", "BrainrotCity", "Backrooms", "Moon", "BrainrotDimension"]:
		_check(ResourceLoader.exists("res://scenes/zones/Slimerot" + scene + ".tscn"), "packed " + scene)
	_check(ResourceLoader.exists("res://scenes/Slimerot.tscn"), "packed main scene")
	_check(FileAccess.file_exists("res://project.binary"), "packed project settings")
	var groups := {"slimes":24, "player":1, "enemies":24, "bosses":4, "zones":8, "structures":9, "ui":10}
	var counts: Dictionary = {}
	for group in groups:
		var paths := _imports(files, "res://assets/art/" + str(group) + "/", ".svg.import")
		counts[group] = paths.size()
		_check(paths.size() == groups[group], "packed %s placeholder count" % group)
		for path in paths:
			_check(ResourceLoader.load(path.trim_suffix(".import")) is Texture2D, "packed texture loads: " + path.get_file())
	var environment_zones := ["backyard", "italian_village", "cursed_forest", "sahara", "brainrot_city", "backrooms", "moon", "brainrot_dimension"]
	var environment_structures := ["boss_portal", "fast_travel_pillar", "gate_closed", "gate_open", "mutation_lab", "portal", "potion_bench", "sell_terminal", "skill_tree_shrine"]
	counts["environment_zones"] = _imports(files, "res://assets/environment/zones/", ".svg.import").size()
	counts["environment_structures"] = _imports(files, "res://assets/environment/structures/", ".svg.import").size()
	_check(counts["environment_zones"] == 32, "packed 32 original zone environment SVGs")
	_check(counts["environment_structures"] == 9, "packed nine original structure SVGs")
	for zone_id in environment_zones:
		for kind in ["obstacle", "rock", "prop", "border"]:
			_check(ResourceLoader.load("res://assets/environment/zones/Slimerot_" + zone_id + "_" + kind + ".svg") is Texture2D, "packed environment loads: " + zone_id + " " + kind)
	for structure_id in environment_structures:
		_check(ResourceLoader.load("res://assets/environment/structures/Slimerot_" + structure_id + ".svg") is Texture2D, "packed structure loads: " + structure_id)
	var mobile_icons := ["team", "collection", "potions", "skills", "settings", "map", "roll", "coins", "luck"]
	counts["mobile_ui"] = _imports(files, "res://assets/ui/icons/", ".svg.import").size()
	_check(counts["mobile_ui"] == mobile_icons.size(), "packed nine original mobile UI icons")
	for id in mobile_icons:
		_check(ResourceLoader.load("res://assets/ui/icons/Slimerot_" + id + ".svg") is Texture2D, "packed mobile icon loads: " + id)
	var mobile_theme := ResourceLoader.load("res://assets/ui/SlimerotTheme.tres") as Theme
	_check(mobile_theme != null, "packed central mobile Theme")
	if mobile_theme != null:
		for variation in ["PrimaryButton", "SecondaryButton", "IconButton", "TabButton", "ModalPanel", "Card", "CurrencyChip", "SkillNode", "LockedSkillNode", "PurchasedSkillNode", "BreakthroughSkillNode"]:
			_check(not mobile_theme.get_type_variation_base(variation).is_empty(), "packed theme variation: " + variation)
	var sounds := _imports(files, "res://assets/audio/", ".wav.import")
	counts["audio"] = sounds.size()
	_check(sounds.size() == 10, "packed ten audio cues")
	for path in sounds:
		_check(ResourceLoader.load(path.trim_suffix(".import")) is AudioStream, "packed audio loads: " + path.get_file())
	_check(ResourceLoader.load("res://assets/Slimerot.svg") is Texture2D, "packed Slimerot app icon")
	var class_cache := ConfigFile.new()
	_check(class_cache.load("res://.godot/global_script_class_cache.cfg") == OK, "packed global class cache")
	for entry in class_cache.get_value("", "list", []):
		_check(entry is Dictionary and ResourceLoader.exists(str(entry.get("path", ""))), "packed class path: " + str(entry.get("class", "unknown")))
	var report := {"schema":"Slimerot.export_audit", "checks":checks, "failures":failures,
		"packed_file_count":files.size(), "asset_counts":counts,
		"pack_sha256":FileAccess.get_sha256(pack_path), "source_fallback_allowed":false}
	if not output_path.is_empty():
		if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK:
			push_error("Slimerot export audit could not create the report directory.")
			quit(1)
			return
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			push_error("Slimerot export audit could not write the report.")
			quit(1)
			return
		output.store_string(JSON.stringify(report, "\t") + "\n")
		output.close()
	print("Slimerot export audit: " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _collect(directory: String, files: Array[String]) -> void:
	for filename in DirAccess.get_files_at(directory):
		files.append(directory.path_join(filename))
	for child in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(child), files)

func _imports(files: Array[String], directory: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	for path in files:
		if path.begins_with(directory) and path.ends_with(suffix): result.append(path)
	return result

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)
