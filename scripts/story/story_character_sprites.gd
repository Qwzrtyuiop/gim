extends RefCounted

# Canonical saved character IDs own their named VN sprite variants.
# Add future expressions/outfits here without changing dialogue speaker names.
const SPRITES := {
	"alma": {
		"default": "res://assets/characters/Alma.png",
	},
	"benny": {
		"default": "res://assets/characters/Benny.png",
	},
	"cel": {
		"default": "res://assets/characters/Celina.png",
	},
	"dante": {
		"default": "res://assets/characters/Dante.png",
	},
	"ely": {
		"default": "res://assets/characters/Elena.png",
	},
	"faye": {
		"default": "res://assets/characters/Magda.png",
		"alt": "res://assets/characters/Magda_alt.png",
	},
	"gardo": {
		"default": "res://assets/characters/Gardo.png",
	},
	"hana": {
		"default": "res://assets/characters/Hana.png",
	},
	"ito": {
		"default": "res://assets/characters/Isidro.png",
	},
	"jessa": {
		"default": "res://assets/characters/Jessa.png",
		"alt": "res://assets/characters/Jessa_alt.png",
	},
	"john": {
		"default": "res://assets/characters/John.png",
	},
	"driver": {
		"default": "res://assets/characters/placeholder.png",
	},
	"passenger": {
		"default": "res://assets/characters/placeholder.png",
	},
	"collector": {
		"default": "res://assets/characters/placeholder.png",
	},
}

const ALIASES := {
	"ben": "benny",
	"celina": "cel",
	"elena": "ely",
	"isidro": "ito",
	"john toda": "john",
	"johntoda": "john",
	"magda": "faye",
	"man outside": "collector",
	"manoutside": "collector",
}
# Arvin and Dylan intentionally have no sprites.


static func canonical_character_id(value: String) -> String:
	var key := value.strip_edges().to_lower()
	key = str(ALIASES.get(key, key))
	return key if SPRITES.has(key) else ""


static func texture_path(character_id: String, sprite := "default") -> String:
	var key := canonical_character_id(character_id)
	if key.is_empty():
		return ""
	var variants: Dictionary = SPRITES[key]
	return str(variants.get(sprite.strip_edges().to_lower(), ""))


static func is_valid(character_id: String, sprite: String) -> bool:
	return not texture_path(character_id, sprite).is_empty()


static func for_speaker(speaker: String, sprite := "default") -> Array:
	var character_id := canonical_character_id(speaker)
	var texture := texture_path(character_id, sprite)
	if texture.is_empty():
		return []
	return [{
		"id": "speaker",
		"character_id": character_id,
		"sprite": sprite.strip_edges().to_lower(),
		"texture": texture,
		"position": "left",
		"height": 300,
	}]
