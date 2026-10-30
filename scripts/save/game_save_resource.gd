extends Resource
class_name GameSaveResource

@export var version := 1
# Keep the default at 1: legacy .tres files can omit it. The codec explicitly
# writes version 5 on new snapshots.
@export var data: Dictionary = {}
# Optional slot information; older resources default to an empty map.
# Version 5 data persists stress/hull; older energy saves migrate in the codec.
# Its optional fish_catches array stores individual per-run catches; older saves
# receive an empty inventory when loaded.
@export var metadata: Dictionary = {}
