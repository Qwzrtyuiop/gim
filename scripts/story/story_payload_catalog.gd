extends RefCounted

# Register each authored story once. Events and the memory library share this list.
# Titles/previews fall back to the payload, so new entries need only both scripts.
const STORIES := {
	"scene_01_intro": {
		"english": preload("res://scripts/story/payloads/intro/scene_01_intro.gd"),
		"tagalog": preload("res://scripts/story/payloads/intro/scene_01_intro_tagalog.gd"),
		"title": "Prologue", "subtitle": "John's first morning as a tricycle driver.",
	},
	"day_02_station_bill": {
		"english": preload("res://scripts/story/payloads/events/day_02_station_bill.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/day_02_station_bill_tagalog.gd"),
		"title": "Day 2", "subtitle": "A folded bill lands at John's feet.",
	},
	"benny_class_clown": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_class_clown.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_class_clown_tagalog.gd"),
		"title": "Class Clown", "subtitle": "Benny asks John what happened in the city.",
	},
	"elena_old_acquaintance": {
		"english": preload("res://scripts/story/payloads/characters/elena/elena_old_acquaintance.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/elena/elena_old_acquaintance_tagalog.gd"),
		"title": "An Old Acquaintance", "subtitle": "An old acquaintance asks John about his father.",
	},
	"benny_construction_introduction": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_construction_introduction.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_construction_introduction_tagalog.gd"),
		"title": "An Extra Pair of Hands",
		"subtitle": "Benny offers John work at the construction site.",
	},
	"benny_construction_work_offer": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_construction_work_offer.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_construction_work_offer_tagalog.gd"),
		"title": "Construction Work",
		"subtitle": "John can help Benny's construction crew for a shift.",
	},
	"north_road_open": {
		"english": preload("res://scripts/story/payloads/events/north_road_open.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/north_road_open_tagalog.gd"),
		"title": "The Road North",
		"subtitle": "The northern road is open again.",
		"preview_image": "res://assets/map/northmap.png",
	},
	"church_prayer_visit_1": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_visit_1.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_visit_1_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_visit_2": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_visit_2.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_visit_2_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_visit_3": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_visit_3.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_visit_3_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_visit_4": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_visit_4.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_visit_4_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_visit_5": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_visit_5.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_visit_5_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_short_1": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_short_1.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_short_1_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_short_2": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_short_2.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_short_2_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_short_3": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_short_3.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_short_3_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_short_4": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_short_4.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_short_4_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"church_prayer_short_5": {
		"english": preload("res://scripts/story/payloads/events/church/church_prayer_short_5.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/church/church_prayer_short_5_tagalog.gd"),
		"title": "Prayer",
		"subtitle": "John takes a moment to pray.",
	},
	"park_visit_1": {
		"english": preload("res://scripts/story/payloads/events/park/park_visit_1.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_visit_1_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_visit_2": {
		"english": preload("res://scripts/story/payloads/events/park/park_visit_2.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_visit_2_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_visit_3": {
		"english": preload("res://scripts/story/payloads/events/park/park_visit_3.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_visit_3_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_visit_4": {
		"english": preload("res://scripts/story/payloads/events/park/park_visit_4.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_visit_4_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_visit_5": {
		"english": preload("res://scripts/story/payloads/events/park/park_visit_5.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_visit_5_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_short_1": {
		"english": preload("res://scripts/story/payloads/events/park/park_short_1.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_short_1_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_short_2": {
		"english": preload("res://scripts/story/payloads/events/park/park_short_2.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_short_2_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_short_3": {
		"english": preload("res://scripts/story/payloads/events/park/park_short_3.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_short_3_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_short_4": {
		"english": preload("res://scripts/story/payloads/events/park/park_short_4.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_short_4_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"park_short_5": {
		"english": preload("res://scripts/story/payloads/events/park/park_short_5.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/park/park_short_5_tagalog.gd"),
		"title": "A Quiet Moment",
		"subtitle": "John takes a break at the park.",
	},
	"jessa_runaway_fare": {
		"english": preload("res://scripts/story/payloads/characters/jessa/jessa_runaway_fare.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/jessa/jessa_runaway_fare_tagalog.gd"),
		"title": "Runaway Fare", "subtitle": "A passenger leaves without paying.",
	},
	"jessa_second_encounter": {
		"english": preload("res://scripts/story/payloads/characters/jessa/jessa_second_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/jessa/jessa_second_encounter_tagalog.gd"),
		"title": "A Familiar Passenger",
		"subtitle": "Jessa appears again at the terminal.",
	},
	"isidro_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/isidro/isidro_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/isidro/isidro_first_encounter_tagalog.gd"),
		"title": "First Warning",
		"subtitle": "Isidro reacts to an unsafe ride.",
	},
	"gardo_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/gardo/gardo_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/gardo/gardo_first_encounter_tagalog.gd"),
		"title": "Not Yet",
		"subtitle": "A passenger asks John to keep driving into the night.",
	},
	"magda_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/magda/magda_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/magda/magda_first_encounter_tagalog.gd"),
		"title": "Magda: First Event",
		"subtitle": "Story placeholder.",
	},
	"hana_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/hana/hana_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/hana/hana_first_encounter_tagalog.gd"),
		"title": "Lost ID 1",
		"subtitle": "John finds an ID card left in his tricycle.",
	},
	"hana_second_encounter": {
		"english": preload("res://scripts/story/payloads/characters/hana/hana_second_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/hana/hana_second_encounter_tagalog.gd"),
		"title": "Lost ID 2",
		"subtitle": "John returns Hana's ID and finds something else she left behind.",
	},
	"celina_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/celina/celina_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/celina/celina_first_encounter_tagalog.gd"),
		"title": "Just a Scratch",
		"subtitle": "An observant passenger insists John take care of a cut.",
	},
	"celina_hospital_introduction": {
		"english": preload("res://scripts/story/payloads/characters/celina/celina_hospital_introduction.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/celina/celina_hospital_introduction_tagalog.gd"),
		"title": "A Familiar Face",
		"subtitle": "John meets the girl who gave him a bandage at the hospital counter.",
	},
	"alma_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/alma/alma_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/alma/alma_first_encounter_tagalog.gd"),
		"title": "Alma: First Event",
		"subtitle": "Story placeholder.",
	},
	"dante_first_encounter": {
		"english": preload("res://scripts/story/payloads/characters/dante/dante_first_encounter.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/dante/dante_first_encounter_tagalog.gd"),
		"title": "Dante: First Event",
		"subtitle": "Story placeholder.",
	},
	"benny_tropa_night": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_tropa_night.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_tropa_night_tagalog.gd"),
		"title": "Tropa", "subtitle": "Old friends meet under city lights.",
		"preview_image": "res://assets/story/backgrounds/locations/bar.png",
	},
	"scene_03_day7_night": {
		"english": preload("res://scripts/story/payloads/events/scene_03_day7_night.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/scene_03_day7_night_tagalog.gd"),
		"title": "Collection", "subtitle": "Debt collection day.",
	},
	"malasakit": {
		"english": preload("res://scripts/story/payloads/events/malasakit.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/malasakit_tagalog.gd"),
		"subtitle": "A passenger reaches the destination without their wallet.",
	},
	"bayanihan": {
		"english": preload("res://scripts/story/payloads/events/bayanihan.gd"),
		# English fallback until a Tagalog script is supplied.
		"tagalog": preload("res://scripts/story/payloads/events/bayanihan.gd"),
		"subtitle": "A stranded driver asks John for a helping hand.",
	},
	"generic_keep_the_change": {
		"english": preload("res://scripts/story/payloads/events/generic/keep_the_change.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/keep_the_change_tagalog.gd"),
		"title": "Keep the Change",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_a_compliment": {
		"english": preload("res://scripts/story/payloads/events/generic/a_compliment.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/a_compliment_tagalog.gd"),
		"title": "A Compliment",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_an_extra_tip": {
		"english": preload("res://scripts/story/payloads/events/generic/an_extra_tip.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/an_extra_tip_tagalog.gd"),
		"title": "An Extra Tip",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_lucky_day": {
		"english": preload("res://scripts/story/payloads/events/generic/lucky_day.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/lucky_day_tagalog.gd"),
		"title": "Lucky Day",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_a_quiet_ride": {
		"english": preload("res://scripts/story/payloads/events/generic/a_quiet_ride.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/a_quiet_ride_tagalog.gd"),
		"title": "A Quiet Ride",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_rounding_up": {
		"english": preload("res://scripts/story/payloads/events/generic/rounding_up.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/rounding_up_tagalog.gd"),
		"title": "Rounding Up",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_a_friendly_passenger": {
		"english": preload("res://scripts/story/payloads/events/generic/a_friendly_passenger.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/a_friendly_passenger_tagalog.gd"),
		"title": "A Friendly Passenger",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_a_small_favor": {
		"english": preload("res://scripts/story/payloads/events/generic/a_small_favor.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/a_small_favor_tagalog.gd"),
		"title": "A Small Favor",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_an_unexpected_conversation": {
		"english": preload("res://scripts/story/payloads/events/generic/an_unexpected_conversation.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/an_unexpected_conversation_tagalog.gd"),
		"title": "An Unexpected Conversation",
		"subtitle": "A small moment with a passenger.",
	},
	"generic_a_generous_stranger": {
		"english": preload("res://scripts/story/payloads/events/generic/a_generous_stranger.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/generic/a_generous_stranger_tagalog.gd"),
		"title": "A Generous Stranger",
		"subtitle": "A small moment with a passenger.",
	},
	"malasakit_epilogue": {
		"english": preload("res://scripts/story/payloads/events/malasakit_epilogue.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/malasakit_epilogue_tagalog.gd"),
		"subtitle": "A familiar passenger returns to settle an old fare.",
	},
}


static func build(story_id: String, next_scene := "", stage_descriptor := "") -> Dictionary:
	var safe_id := story_id.strip_edges().to_lower()
	match safe_id:
		"day_2_station_bill":
			safe_id = "day_02_station_bill"
		"day_7_night_scene_03":
			safe_id = "scene_03_day7_night"
	if not STORIES.has(safe_id):
		return {}
	var definition: Dictionary = STORIES[safe_id]
	var script: Script = definition["tagalog" if StoryLanguageManager.is_tagalog() else "english"]
	if safe_id == "scene_01_intro":
		return script.build(next_scene, stage_descriptor)
	return script.build()


static func memory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for story_id in STORIES:
		var definition: Dictionary = STORIES[story_id]
		var payload := build(story_id)
		if payload.is_empty():
			continue
		entries.append({
			"id": story_id,
			"title": definition.get("title", payload.get("chapter_title", story_id)),
			"subtitle": definition.get("subtitle", "A moment from John's journey."),
			"unlock_story_id": story_id,
			"preview_image": definition.get("preview_image", payload.get("background", "")),
		})
	return entries
