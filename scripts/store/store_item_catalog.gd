extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")

# Compatibility entry point; all editable inventory data lives in GameTuning.
const ITEMS := GameTuning.STORE_ITEMS
