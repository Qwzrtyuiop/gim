extends RefCounted

# Speaker aliases share artwork across both story languages.
const PORTRAITS := {
	"driver": "res://assets/characters/placeholder.png",
	"passenger": "res://assets/characters/placeholder.png",
	"john": "res://assets/characters/John.png",
	"john toda": "res://assets/characters/John.png",
	"benny": "res://assets/characters/Benny.png",
	"ben": "res://assets/characters/Benny.png",
	"collector": "res://assets/characters/placeholder.png",
	"man outside": "res://assets/characters/placeholder.png",
}
# Arvin and Dylan intentionally have no sprites.


static func for_speaker(speaker: String) -> Array:
	var key := speaker.strip_edges().to_lower()
	var texture := str(PORTRAITS.get(key, ""))
	if texture.is_empty():
		return []
	return [{
		"id": "speaker",
		"texture": texture,
		"position": "left",
		"height": 300,
	}]
