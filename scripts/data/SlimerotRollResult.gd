class_name SlimerotRollResult
extends RefCounted

# A resolved Slimerot roll owns no rewards until the manager commits it once.
var data: Dictionary = {}
var expected_lifetime := 0
var generation := 0
var committed := false
