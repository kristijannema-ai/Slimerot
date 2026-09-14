extends SceneTree

# Run with --headless --path <Slimerot> --script res://tools/SlimerotPacingEstimator.gd --
# --slimerot-estimate --slimerot-estimate-output=<absolute filename stem> --slimerot-estimate-seeds=12
# Exported reports belong outside the repository. This runner never edits a save.
const MODEL = preload("res://tools/SlimerotPacingModel.gd")

func _initialize() -> void:
	# --script omits the main scene, but Godot still creates project autoloads.
	# Disable saves before synchronous estimation or shutdown can save player state.
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.set("enabled", false)
		save_manager.set_process(false)
	if "--slimerot-estimate" not in OS.get_cmdline_user_args():
		push_error("Slimerot estimator requires --slimerot-estimate to isolate it from player saves.")
		quit(1)
		return
	if not OS.is_debug_build():
		push_error("Slimerot pacing estimation is available only in a developer build.")
		quit(1)
		return
	var configuration: Dictionary = {}
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--slimerot-estimate-output="):
			output = argument.trim_prefix("--slimerot-estimate-output=")
		elif argument.begins_with("--slimerot-estimate-seeds="):
			configuration.seeds = int(argument.trim_prefix("--slimerot-estimate-seeds="))
		elif argument.begins_with("--slimerot-estimate-combat-utilisation="):
			configuration.combat_utilisation = float(argument.trim_prefix("--slimerot-estimate-combat-utilisation="))
		elif argument.begins_with("--slimerot-estimate-boss-utilisation="):
			configuration.boss_utilisation = float(argument.trim_prefix("--slimerot-estimate-boss-utilisation="))
		elif argument.begins_with("--slimerot-estimate-travel-seconds="):
			configuration.travel_seconds = float(argument.trim_prefix("--slimerot-estimate-travel-seconds="))
	var model = MODEL.new()
	var report: Dictionary = model.run(configuration)
	var summary: String = model.text_summary(report)
	print(summary)
	if not output.is_empty():
		if output.ends_with(".json"): output = output.trim_suffix(".json")
		var parent := output.get_base_dir()
		if not parent.is_empty() and DirAccess.make_dir_recursive_absolute(parent) != OK:
			push_error("Slimerot could not create estimate output directory: " + parent)
			quit(1)
			return
		for entry in [[".json", JSON.stringify(report, "\t") + "\n"], [".txt", summary]]:
			var file := FileAccess.open(output + str(entry[0]), FileAccess.WRITE)
			if file == null:
				push_error("Slimerot could not export estimate: " + output + str(entry[0]))
				quit(1)
				return
			file.store_string(entry[1])
			file.flush()
			var write_error := file.get_error()
			file.close()
			if write_error != OK:
				push_error("Slimerot could not finish estimate export: " + output + str(entry[0]))
				quit(1)
				return
		print("Slimerot estimate exported to " + output + ".json and .txt")
	quit(0)
