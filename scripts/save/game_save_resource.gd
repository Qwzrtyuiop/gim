extends Resource
class_name GameSaveResource

@export var version := 1
@export var data: Dictionary = {}
# Optional slot information; older version-4 resources default to an empty map.
@export var metadata: Dictionary = {}
