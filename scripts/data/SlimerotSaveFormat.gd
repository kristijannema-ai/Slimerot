class_name SlimerotSaveFormat
extends RefCounted

# Slimerot keeps JSON data inert; no object/resource deserialization or network access.
const FORMAT := "Slimerot"
const SUFFIXES := ["", ".tmp", ".bak", ".recover", ".reset"]
const MAX_EXACT_INTEGER := 9007199254740991

static func encode(state: Dictionary, generation: int) -> String:
	# Hash the exact payload bytes, independent of JSON's int/float round trip.
	var payload := JSON.stringify(state)
	return JSON.stringify({"format": FORMAT, "generation": generation,
		"payload": payload, "checksum": digest(payload, generation)})

static func digest(payload: String, generation: int) -> String:
	return (FORMAT + "\n" + str(generation) + "\n" + payload).sha256_text()

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var bytes := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(bytes) != OK or not parser.data is Dictionary: return {}
	var value: Dictionary = parser.data
	if value.has("schema_version"):
		return {"state": value, "generation": 0} # Plain legacy schemas 1–6.
	if value.get("format") != FORMAT or not value.get("payload") is String or not value.get("checksum") is String:
		return {}
	if not integer(value.get("generation")) or value.generation < 1: return {}
	if value.checksum != digest(value.payload, int(value.generation)): return {}
	if parser.parse(value.payload) != OK or not parser.data is Dictionary: return {}
	return {"state": parser.data, "generation": int(value.generation)}

static func integer(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0 and value <= MAX_EXACT_INTEGER and float(value) == floor(float(value))

static func write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK
