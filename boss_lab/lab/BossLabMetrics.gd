class_name BLMetrics
extends RefCounted

## The lab owns this local history; it never reads the main game's saves.
const MAX_RECORDS := 500
const SAVE_PATH := "user://boss-lab-attempts.json"
const FORMAT_VERSION := 2
const BOSS_IDS := ["espresso", "sand", "janitor", "admin"]

var records: Array[Dictionary] = []
var _aggregates: Dictionary = {}
var storage_path := SAVE_PATH
var persistence_enabled := not Array(OS.get_cmdline_user_args()).any(func(arg): return arg in ["--boss-lab-test", "--boss-lab-capture"])
var last_storage_error := ""

func load_local() -> void:
	if not persistence_enabled:
		return
	var decoded: Dictionary = {}
	var restored := false
	for candidate in [storage_path, storage_path + ".previous", storage_path + ".pending"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var value: Variant = parser.data
		if value is Dictionary and value.get("records", null) is Array:
			decoded = value
			restored = candidate != storage_path
			break
	if decoded.is_empty():
		if FileAccess.file_exists(storage_path):
			last_storage_error = "Local attempt history was invalid; starting an empty history."
		return
	records.clear()
	_aggregates.clear()
	for value in decoded.records:
		if value is Dictionary:
			var record := _normalise(value)
			if not record.boss_id.is_empty():
				records.append(record)
				_accumulate(record)
	while records.size() > MAX_RECORDS:
		records.pop_front()
	# Detailed history is capped; small all-time aggregates retain first clears and numbering.
	var aggregate_source: Variant = decoded.get("aggregates", {})
	if aggregate_source is Dictionary:
		for boss_id in BOSS_IDS:
			for mode in ["normal", "practice"]:
				var key := _key(boss_id, mode)
				var aggregate: Variant = aggregate_source.get(key, null)
				if aggregate is Dictionary and int(_number(aggregate.get("attempts", 0), 0.0)) >= int(_aggregates.get(key, {}).get("attempts", 0)):
					_aggregates[key] = _clean_aggregate(aggregate)
	last_storage_error = "Recovered the last complete local history." if restored else ""

func save_local() -> void:
	if not persistence_enabled:
		return
	# An interrupted write retains the last complete history.
	var pending_path := storage_path + ".pending"
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		last_storage_error = "Could not write local attempt history."
		return
	file.store_string(JSON.stringify({"version": FORMAT_VERSION, "records": records, "aggregates": _aggregates}))
	file.flush()
	file.close()
	var target_path := ProjectSettings.globalize_path(storage_path)
	var staged_path := ProjectSettings.globalize_path(pending_path)
	var backup_path := target_path + ".previous"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(target_path):
		if DirAccess.rename_absolute(target_path, backup_path) != OK:
			last_storage_error = "Could not retain the previous local history."
			return
	if DirAccess.rename_absolute(staged_path, target_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, target_path)
		last_storage_error = "Could not finish the local history save."
		return
	last_storage_error = ""

func record_attempt(value: Dictionary) -> void:
	var record := _normalise(value)
	if record.boss_id.is_empty():
		return
	records.append(record)
	_accumulate(record)
	while records.size() > MAX_RECORDS:
		records.pop_front()
	save_local()

func next_attempt_number(boss_id: String, mode: String = "normal") -> int:
	return int(_aggregates.get(_key(boss_id, mode), {}).get("max_attempt", 0)) + 1

func summary(boss_id: String, mode: String = "normal") -> Dictionary:
	var result: Dictionary = _aggregates.get(_key(boss_id, mode), _empty_aggregate()).duplicate(true)
	result["boss_id"] = boss_id
	result["mode"] = mode
	result["average_survival_seconds"] = float(result.duration_total) / float(result.attempts) if int(result.attempts) > 0 else 0.0
	result["most_common_death_attack"] = "—"
	result["history_limit"] = MAX_RECORDS
	var highest_count := 0
	var names: Array = result.death_counts.keys()
	names.sort()
	for attack in names:
		if int(result.death_counts[attack]) > highest_count:
			highest_count = int(result.death_counts[attack])
			result.most_common_death_attack = attack
	return result

func _key(boss_id: String, mode: String) -> String:
	return boss_id + "/" + mode

func _empty_aggregate() -> Dictionary:
	return {
		"attempts": 0, "wins": 0, "max_attempt": 0, "duration_total": 0.0,
		"best_hp_before_first_clear": 100.0, "first_clear_attempt": 0,
		"hits": 0, "dash_count": 0, "damage_by_attack": {}, "death_counts": {},
	}

func _accumulate(record: Dictionary) -> void:
	var key := _key(record.boss_id, record.mode)
	var result: Dictionary = _aggregates.get(key, _empty_aggregate())
	result.attempts += 1
	result.max_attempt = maxi(result.max_attempt, record.attempt)
	result.duration_total += record.duration
	result.hits += record.hits
	result.dash_count += record.dash_count
	for attack in record.damage_by_attack:
		if result.damage_by_attack.has(attack) or result.damage_by_attack.size() < 64:
			result.damage_by_attack[attack] = float(result.damage_by_attack.get(attack, 0.0)) + float(record.damage_by_attack[attack])
	if record.victory:
		result.wins += 1
		if result.first_clear_attempt == 0:
			result.first_clear_attempt = record.attempt
	else:
		if result.first_clear_attempt == 0:
			result.best_hp_before_first_clear = minf(result.best_hp_before_first_clear, record.boss_hp_remaining)
		if not record.interrupted and not record.death_attack.is_empty() and (result.death_counts.has(record.death_attack) or result.death_counts.size() < 64):
			result.death_counts[record.death_attack] = int(result.death_counts.get(record.death_attack, 0)) + 1
	_aggregates[key] = result

func _clean_aggregate(value: Dictionary) -> Dictionary:
	var result := _empty_aggregate()
	for field in ["attempts", "wins", "max_attempt", "first_clear_attempt", "hits", "dash_count"]:
		result[field] = maxi(0, int(_number(value.get(field, 0), 0.0)))
	result.duration_total = maxf(0.0, _number(value.get("duration_total", 0.0), 0.0))
	result.best_hp_before_first_clear = clampf(_number(value.get("best_hp_before_first_clear", 100.0), 100.0), 0.0, 100.0)
	for field in ["damage_by_attack", "death_counts"]:
		var source: Variant = value.get(field, {})
		if source is Dictionary:
			for name in source:
				if result[field].size() >= 64:
					break
				result[field][str(name)] = maxf(0.0, _number(source[name], 0.0))
	return result

func _normalise(value: Dictionary) -> Dictionary:
	var damage: Dictionary = {}
	var source_damage: Variant = value.get("damage_by_attack", {})
	if source_damage is Dictionary:
		for attack in source_damage:
			if damage.size() >= 64:
				break
			var amount := _number(source_damage[attack], 0.0)
			if amount > 0.0:
				damage[str(attack)] = amount
	return {
		"boss_id": str(value.get("boss_id", "")) if str(value.get("boss_id", "")) in BOSS_IDS else "",
		"boss_name": str(value.get("boss_name", value.get("boss_id", ""))),
		"mode": "practice" if str(value.get("mode", "normal")) == "practice" else "normal",
		"attempt": maxi(1, int(_number(value.get("attempt", 1), 1.0))),
		"duration": maxf(0.0, _number(value.get("duration", 0.0), 0.0)),
		"phase": maxi(1, int(_number(value.get("phase", 1), 1.0))),
		"boss_hp_remaining": clampf(_number(value.get("boss_hp_remaining", 100.0), 100.0), 0.0, 100.0),
		"hits": maxi(0, int(_number(value.get("hits", 0), 0.0))),
		"dash_count": maxi(0, int(_number(value.get("dash_count", 0), 0.0))),
		"damage_by_attack": damage,
		"damage_taken": maxf(0.0, _number(value.get("damage_taken", 0.0), 0.0)),
		"death_attack": str(value.get("death_attack", "")),
		"interrupted": str(value.get("death_attack", "")) in ["Restarted", "Returned to menu", "Changed mode", "Changed encounter"],
		"victory": bool(value.get("victory", false)),
		"seed": int(_number(value.get("seed", 0), 0.0)),
		"dps": maxf(0.0, _number(value.get("dps", 0.0), 0.0)),
		"dps_preset": str(value.get("dps_preset", "EXPECTED")),
		"timestamp": str(value.get("timestamp", "")),
		"recorded_at": int(_number(value.get("recorded_at", Time.get_unix_time_from_system()), Time.get_unix_time_from_system())),
	}

func _number(value: Variant, fallback: float) -> float:
	if not value is int and not value is float:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback
