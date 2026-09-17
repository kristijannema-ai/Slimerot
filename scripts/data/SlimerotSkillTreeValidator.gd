class_name SlimerotSkillTreeValidator
extends RefCounted

# These roots deliberately have no skill prerequisite; Coin roots still have
# their shrine, zone, boss or structure gate. New independent roots are explicit.
const ROOT_IDS := ["R01", "C01", "C07", "C09", "CO1", "C20"]
const BREAKTHROUGH_IDS := ["R08", "R13", "R18"]

# Accept the original definition list, not an ID dictionary which has already
# discarded duplicate IDs. Dictionaries are also accepted for debug fixtures.
static func validate(node_list: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var ids: Dictionary = {}
	var persistent_ids: Dictionary = {}
	var graph: Dictionary = {}
	for data in node_list:
		if not (data is Dictionary or data is SlimerotData.SkillNodeData):
			errors.append("Invalid node definition type")
			continue
		var raw_id: Variant = field(data, "id", "")
		if not raw_id is String or raw_id.is_empty():
			errors.append("Node ID must be a nonempty string")
			continue
		var id: String = raw_id
		if ids.has(id): errors.append("Duplicate node ID: " + id)
		ids[id] = true
		var persistent_id: Variant = data.get("persistent_id", id) if data is Dictionary else id
		if not persistent_id is String or persistent_id.is_empty():
			errors.append("Invalid persistent ID: " + id)
		elif persistent_ids.has(persistent_id):
			errors.append("Duplicate persistent ID: " + persistent_id)
		else:
			persistent_ids[persistent_id] = id
		var currency: Variant = field(data, "currency_type", "")
		if currency not in ["Rolls", "Coins"]:
			errors.append("Invalid currency for " + id + ": " + str(currency))
		var cost: Variant = field(data, "cost", -1)
		if not (cost is int or cost is float) or not is_finite(float(cost)) or float(cost) < 0 or float(cost) != floor(float(cost)):
			errors.append("Invalid cost: " + id)
		var effect: Variant = field(data, "effect_type", "")
		var value: Variant = field(data, "effect_value", 0)
		var numeric_value: bool = (value is int or value is float) and is_finite(float(value))
		if not numeric_value:
			errors.append("Invalid effect value: " + id)
		elif effect in ["slot_set", "slot_add"] and (float(value) > 5.0 or float(value) < 1.0 or float(value) != floor(float(value))):
			errors.append("Slot effect must be an integer from 1 to 5: " + id)
		if effect == "checkpoint_luck" or id in BREAKTHROUGH_IDS:
			if effect != "checkpoint_luck" or not numeric_value or float(value) != 20.0:
				errors.append("Breakthrough must multiply luck exactly x20: " + id)
		var prerequisites: Variant = field(data, "prerequisite_ids", [])
		if prerequisites is String:
			prerequisites = [] if prerequisites.is_empty() else [prerequisites]
		if not prerequisites is Array:
			errors.append("Invalid prerequisite list: " + id)
			prerequisites = []
		var links: Array[String] = []
		for prerequisite in prerequisites:
			if not prerequisite is String or prerequisite.is_empty():
				errors.append("Invalid prerequisite ID: " + id)
			elif prerequisite in links:
				warnings.append("Repeated prerequisite " + prerequisite + " on " + id)
			else:
				links.append(prerequisite)
		# Keep the first definition in a duplicate pair so its edges remain visible.
		if not graph.has(id): graph[id] = links
	for id in graph:
		for prerequisite in graph[id]:
			if not ids.has(prerequisite): errors.append("Missing prerequisite " + prerequisite + " for " + id)
	var colors: Dictionary = {}
	for id in graph: visit(id, graph, colors, [], errors)
	for id in graph:
		if not reaches_root(id, graph, {}): warnings.append("Orphan node has no path to an intentional root: " + id)
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings, "node_count": node_list.size()}

static func field(data: Variant, key: String, fallback: Variant) -> Variant:
	if data is Dictionary: return data.get(key, fallback)
	return data.get(key)

static func visit(id: String, graph: Dictionary, colors: Dictionary, path: Array, errors: Array[String]) -> void:
	if not graph.has(id) or int(colors.get(id, 0)) == 2: return
	if int(colors.get(id, 0)) == 1:
		var cycle: Array = path.duplicate()
		cycle.append(id)
		errors.append("Cycle in skill prerequisites: " + " -> ".join(cycle))
		return
	colors[id] = 1
	path.append(id)
	for prerequisite in graph[id]: visit(prerequisite, graph, colors, path, errors)
	path.pop_back()
	colors[id] = 2

static func reaches_root(id: String, graph: Dictionary, seen: Dictionary) -> bool:
	if not graph.has(id) or seen.has(id): return false
	if graph[id].is_empty(): return id in ROOT_IDS
	seen[id] = true
	for prerequisite in graph[id]:
		if reaches_root(prerequisite, graph, seen): return true
	return false
