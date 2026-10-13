extends RefCounted

const MetricsScript := preload("res://lab/BossLabMetrics.gd")

func run(_session: Node, runner: Node) -> void:
	var metrics := MetricsScript.new()
	metrics.persistence_enabled = false
	runner.check(metrics.records.is_empty(), "Local metrics start empty in isolated tests")
	metrics.record_attempt(_record("espresso", "normal", 1, 60, 45, false, "Caffeine Charge"))
	metrics.record_attempt(_record("espresso", "normal", 2, 90, 18, false, "Espresso Slam"))
	metrics.record_attempt(_record("espresso", "normal", 3, 121, 0, true, ""))
	metrics.record_attempt(_record("espresso", "normal", 4, 100, 5, false, "Espresso Slam"))
	metrics.record_attempt(_record("espresso", "practice", 1, 20, 0, true, ""))
	var data := metrics.summary("espresso", "normal")
	runner.check(data.attempts == 4 and data.wins == 1, "Normal attempts and wins have separate practice history")
	runner.check(is_equal_approx(data.average_survival_seconds, 92.75), "Average survival includes every completed result")
	runner.check(data.first_clear_attempt == 3, "First clear preserves the actual attempt number")
	runner.check(is_equal_approx(data.best_hp_before_first_clear, 18.0), "Later deaths cannot overwrite the best HP before the first clear")
	runner.check(data.most_common_death_attack == "Espresso Slam", "Common death identifies the real source tag")
	runner.check(data.hits == 8 and data.dash_count == 32, "Local summary accumulates hits and Dash count")
	runner.check(is_equal_approx(data.damage_by_attack["Caffeine Charge"], 27.0), "Damage by attack accumulates the recorded source")
	runner.check(metrics.summary("espresso", "practice").attempts == 1, "Practice result has its own summary")
	runner.check(metrics.next_attempt_number("espresso", "normal") == 5, "Normal attempt sequence ignores practice results")
	runner.check(metrics.next_attempt_number("espresso", "practice") == 2, "Practice attempt sequence is independent")
	runner.check(metrics.summary("sand").attempts == 0, "Other bosses keep independent histories")
	metrics.record_attempt(_record("janitor", "normal", 1, 8, 90, false, "Restarted"))
	runner.check(metrics.summary("janitor").attempts == 1 and metrics.summary("janitor").most_common_death_attack == "—", "Restarted attempts count without inventing a killing attack")
	for number in range(1, 502):
		metrics.record_attempt(_record("sand", "normal", number, 30, 80, false, "Sand Wall"))
	runner.check(metrics.records.size() == 500, "Detailed local history is capped at 500 records")
	runner.check(metrics.summary("sand").attempts == 501, "All-time attempts survive detailed history truncation")
	runner.check(metrics.summary("espresso").first_clear_attempt == 3, "Old first clears survive another boss displacing all detailed records")
	runner.check(metrics.next_attempt_number("espresso") == 5, "History cap never resets an old boss attempt sequence")
	runner.check(metrics.next_attempt_number("sand") == 502, "History cap never resets the current sequence")
	metrics.record_attempt({"boss_id": "admin", "attempt": 1})
	runner.check(metrics.summary("admin").attempts == 1, "Missing optional metrics load with safe defaults")
	metrics.record_attempt({"boss_id": "unknown", "damage_by_attack": "invalid"})
	runner.check(metrics.summary("unknown").attempts == 0, "Unknown local boss IDs are safely ignored")
	var isolated_path := "res://.godot/boss-lab-metrics-test.json"
	for suffix in ["", ".previous", ".pending"]:
		if FileAccess.file_exists(isolated_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_path + suffix))
	metrics.storage_path = isolated_path
	metrics.persistence_enabled = true
	metrics.save_local()
	runner.check(metrics.last_storage_error.is_empty(), "Atomic local metrics save writes to an isolated test path")
	var loaded := MetricsScript.new()
	loaded.storage_path = isolated_path
	loaded.persistence_enabled = true
	loaded.load_local()
	runner.check(loaded.records.size() == 500, "Local save/load preserves the detailed history cap")
	runner.check(loaded.summary("espresso").first_clear_attempt == 3, "Local save/load preserves older all-time first-clear data")
	runner.check(loaded.summary("sand").attempts == 501, "Local save/load preserves all-time attempts")
	runner.check(loaded.summary("espresso", "practice").wins == 1, "Local save/load preserves independent practice totals")
	runner.check(loaded.next_attempt_number("espresso") == 5, "Local save/load preserves older attempt numbering")
	loaded.save_local()
	var interrupted := FileAccess.open(isolated_path, FileAccess.WRITE)
	if interrupted != null:
		interrupted.store_string("interrupted")
		interrupted.close()
	var recovered := MetricsScript.new()
	recovered.storage_path = isolated_path
	recovered.persistence_enabled = true
	recovered.load_local()
	runner.check(recovered.summary("sand").attempts == 501, "Interrupted history write recovers the last complete backup")
	runner.check(not recovered.last_storage_error.is_empty(), "Recovered history displays an explicit storage note")
	for suffix in ["", ".previous", ".pending"]:
		if FileAccess.file_exists(isolated_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_path + suffix))

func _record(boss_id: String, mode: String, number: int, duration: float, hp: float, victory: bool, attack: String) -> Dictionary:
	return {"boss_id": boss_id, "boss_name": boss_id, "mode": mode, "attempt": number,
		"duration": duration, "phase": 2, "boss_hp_remaining": hp, "hits": 2, "dash_count": 8,
		"damage_by_attack": {} if attack.is_empty() else {attack: 27.0}, "death_attack": attack,
		"victory": victory, "seed": 31017}
