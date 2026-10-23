extends RefCounted

const DEFAULT_UNIQUE_STORY_STAGE_SET_ID := "default_unique_story"
const DEFAULT_UNIQUE_STORY_STAGES := [
	{
		"id": "introduction",
		"title": "Introduction",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 0,
		"modifiers": {},
		"modifier_rules": [],
	},
	{
		"id": "familiar",
		"title": "Familiar Face",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 2,
		"modifiers": {},
		"modifier_rules": [],
	},
	{
		"id": "turning_point",
		"title": "Turning Point",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 5,
		"modifiers": {},
		"modifier_rules": [],
	},
]

const DEFAULT_SESSION_DIALOGUE := {
	"go_faster": [
		{
			"english": "Go faster, will you?",
			"tagalog": "Pakibilisan naman o.",
		},
	],
	"hurry_up": [
		{
			"english": "Hurry up!",
			"tagalog": "Grabe, ang bagal.",
		},
	],
	"slow_down": [
		{
			"english": "Slow down.",
			"tagalog": "Pakibagalan po.",
		},
	],
	"careful": [
		{
			"english": "Drive more carefully.",
			"tagalog": "Pakiingatan po.",
		},
	],
	"special": [],
}

const UNIQUE_SESSION_DIALOGUE_OVERRIDES := {
	"alma": {
		"special_1": [
			{"english": "Didn't think I'd run into you out here again, John.", "tagalog": "Dito ka pala nakatira?"},
			{"english": "City nights taught me one thing: never trust a quiet street.", "tagalog": "Kung may natutunan man ako sa siyudad, ito ay huwag magtiwala sa tahimik na kalsada."},
		],
	},
	"benny": {
		"special_1": [
			{"english": "It's been a long time since I've seen you around here. What happened to your city job?", "tagalog": "Long time no see pre, Kala ko ba doon ka nagtratrabaho sa siyudad?"},
			{"english": "Remember me? We used to hang out a lot during high school.", "tagalog": "Naaalala mo pa ako? Tayo yung laging magkakasama nung high school."},
		],
		"special_2": [
			{"english": "Construction starts early. If I'm late, the foreman will chew me out.", "tagalog": "Maaga nanaman ang pasok. Sana di ako masigawan ni porman."},
			{"english": "Funny, no? We used to cut class. Now we're the ones getting chased by time.", "tagalog": "Dati pa cutting cutting pa tayo, ngayon tayo na ang hinahabol ng oras.."},
		],
	},
	"cel": {
		"special_1": [
			{"english": "You can tell a lot about a person by how they drive when they're tired.", "tagalog": "Masasabi mo lang na kilala mo ang isang tao pag nakita mo na siya na magmaneho."},
			{"english": "The clinic is always full...", "tagalog": "Punuan nanaman siguro sa trabaho."},
		],
	},
	"dante": {
		"special_1": [
			{"english": "Night shift leaves the grease on your hands and the noise in your head.", "tagalog": "Paminsan-minsan, ang katahimikan lang ng gabi ang nagpapatila sa ingay ng aking ulo."},
			{"english": "Some things are easier to say when the engines are louder than people.", "tagalog": "Mas madaling intidihin ang mga makina kaysa sa mga tao."},
		],
	},
	"ely": {
		"special_1": [
			{"english": "Your father used to look just as stubborn behind the wheel.", "tagalog": "Naaalala ko ang tatay mo tuwing nakikita kita."},
			{"english": "A teacher learns to spot worry before a student says a word.", "tagalog": "Alam nang guro na may problema bago pa magsalita ang estudyante."},
		],
	},
	"faye": {
		"special_1": [
			{"english": "The men who talk sweet are usually the ones hiding the ugliest things.", "tagalog": "Yung mga lalaking matamis magsalita, sila kadalasan ang may pinakatagong kapangitan."},
			{"english": "You hear everything working nights. Most of it isn't worth hearing.", "tagalog": "Marami kang maririnig habang nagtratrabaho sa gabi na madalas mas mabuni nalang na di mo narinig."},
		],
	},
	"gardo": {
		"special_1": [
			{"english": "Some days I stay at the office just to avoid going home too early.", "tagalog": "May mga araw na nagpapagabi ako sa opisina para lang hindi ako umuwi."},
			{"english": "A necktie makes people think you're doing fine. That's the joke of it.", "tagalog": "Sabi nila mas dadali ang buhay pag may pamilya ka na."},
		],
	},
	"hana": {
		"special_1": [
			{"english": "Rumors get cleaner on paper, but messier in real life.", "tagalog": "May mga bagay na mas madaling mabasa sa papel kaysa makita mo nang harapan."},
			{"english": "If people keep lowering their voice around a story, it usually means it's real.", "tagalog": "Madalas ang katahimikan ay sinyales na may nangyayari."},
		],
	},
	"ito": {
		"special_1": [
			{"english": "People think we see everything. Truth is, we mostly see what we're told to ignore.", "tagalog": "Gano katagal pa ang aking hihintayin bago may magbago."},
			{"english": "Let's not stop too long.", "tagalog": "Sana walang mangyari ngayong araw."},
		],
	},
	"jessa": {
		"special_1": [
			{"english": "If anyone asks, you didn't see me.", "tagalog": "Kapag may naghanap saakin, hindi mo ako nakita."},
			{"english": "I just need a little more time before I go back.", "tagalog": "Kaya ko pa to..."},
		],
	},
}

const GENERIC_PASSENGERS := [
	{
		"id": "generic_guy",
		"name": "Guy",
		"blurb": "Just another rider heading somewhere.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_vendor",
		"name": "Vendor",
		"blurb": "A market seller with goods to move.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_student",
		"name": "Student",
		"blurb": "A student on the way to class or home.",
		"is_generic": true,
		"first_distance": "medium",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_worker",
		"name": "Worker",
		"blurb": "A worker chasing the next shift.",
		"is_generic": true,
		"first_distance": "medium",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_elder",
		"name": "Elder",
		"blurb": "An elder traveling at their own pace.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "generic_parent_child",
		"name": "Parent with Child",
		"blurb": "A parent trying to get their child across town.",
		"is_generic": true,
		"first_distance": "long",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["medium", "long"],
	},
]

const MOCK_CHARACTERS := [
	{
		"id": "alma",
		"name": "Alma",
		"blurb": "Bartender from the city who knows you personally.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.03},
		"first_distance": "short",
		"first_appearance_chance": 0.85,
		"eligible_distances": ["short", "medium"],
		"eligible_times": ["morning", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "First Bargain"},
			"familiar": {"title": "Regular Customer"},
			"turning_point": {"title": "A Bartender's Life"},
		},
	},
	{
		"id": "benny",
		"name": "Benny",
		"blurb": "Former classmate working construction.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.05},
		"first_distance": "medium",
		"first_appearance_chance": 0.70,
		"eligible_distances": ["medium","long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Old Jokester"},
			"familiar": {"title": "Benny's Hustle"},
			"turning_point": {"title": "A Risky Favor"},
		},
	},
	{
		"id": "cel",
		"name": "Celina",
		"blurb": "Clinic aide who is quietly very observant.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.02},
		"first_distance": "short",
		"first_appearance_chance": 0.55,
		"eligible_distances": ["medium", "long"],
		"eligible_times": ["morning", "noon", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Sharp Eyes"},
			"familiar": {"title": "Clinic Errands"},
			"turning_point": {"title": "Celina Knows"},
		},
	},
	{
		"id": "dante",
		"name": "Dante",
		"blurb": "Night shift mechanic carrying a secret.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.1},
		"first_distance": "long",
		"first_appearance_chance": 0.65,
		"eligible_distances": ["short","medium", "long"],
		"eligible_times": ["night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "After Hours"},
			"familiar": {"title": "Shop Talk"},
			"turning_point": {"title": "Dante's Secret"},
		},
	},
	{
		"id": "ely",
		"name": "Elena",
		"blurb": "Teacher who knew your father well.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.02},
		"first_distance": "short",
		"first_appearance_chance": 0.45,
		"eligible_distances": ["short","long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "A Familiar Name"},
			"familiar": {"title": "Lessons Remembered"},
			"turning_point": {"title": "Your Father's Past"},
		},
	},
		{
			"id": "faye",
			"name": "Magda",
			"blurb": "Red light district worker who reads people fast.",
			"ride_modifiers": {"fare_php_per_meter_multiplier": 1.05},
			"first_distance": "medium",
			"first_appearance_chance": 0.80,
			"eligible_distances": ["short", "medium","long"],
			"eligible_times": ["night"],
			"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
			"story_stage_overrides": {
				"introduction": {"title": "Salon Chatter"},
				"familiar": {"title": "Magda Hears Things"},
				"turning_point": {"title": "A Name Dropped"},
			},
		},
	{
		"id": "gardo",
		"name": "Gardo",
		"blurb": "Office worker quietly dealing with family problems.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.12},
		"first_distance": "long",
		"first_appearance_chance": 0.40,
		"eligible_distances": ["long"],
		"eligible_times": ["morning", "noon","night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "All Smiles"},
			"familiar": {"title": "Too Close to Trouble"},
			"turning_point": {"title": "Gardo's Message"},
		},
	},
	{
		"id": "hana",
		"name": "Hana",
		"blurb": "Student journalist chasing rumors.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.03},
		"first_distance": "medium",
		"first_appearance_chance": 0.60,
		"eligible_distances": ["medium", "long"],
		"eligible_times": ["morning", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Notebook Ready"},
			"familiar": {"title": "Questions on the Road"},
			"turning_point": {"title": "Hana Connects the Dots"},
		},
	},
	{
		"id": "ito",
		"name": "Isidro",
		"blurb": "Corrupt barangay tanod who looks perpetually worn down.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": 1.09},
		"first_distance": "long",
		"first_appearance_chance": 0.35,
		"eligible_distances": ["short", "medium", "long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Late Paperwork"},
			"familiar": {"title": "Missing Records"},
			"turning_point": {"title": "Isidro Slips Up"},
		},
	},
	{
		"id": "jessa",
		"name": "Jessa",
		"name_unlock_event": "jessa_name_revealed",
		"blurb": "Runaway youth hiding from her family.",
		"ride_modifiers": {"fare_php_per_meter_multiplier": .99},
		"first_distance": "short",
		"first_appearance_chance": 0.75,
		"eligible_distances": ["short", "medium"],
		"eligible_times": ["night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "A Quiet Ride"},
			"familiar": {"title": "Jessa Returns"},
			"turning_point": {"title": "What Jessa Carries"},
		},
	},
]
