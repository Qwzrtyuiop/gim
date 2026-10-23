extends RefCounted

const CHILL_MUSIC := {
	"type": "play_music",
	"path": "res://assets/audio/music/driving/morning_chill.mp3",
	"loop": true,
	"fade_in": 0.0,
	"fade_out": 0.0,
	"volume_db": -9.0,
	"restart": false,
}


static func build() -> Dictionary:
	return build_scene([
		{"text": "I was driving along my usual route when the elderly woman sitting behind me suddenly spoke."},
		{"speaker": "Elena", "text": "Excuse me, young man."},
		{"speaker": "John Toda", "text": "Yes?"},
		{"speaker": "Elena", "text": "Is that you, John?"},
		{"speaker": "John Toda", "text": "Huh?"},
		{"speaker": "Elena", "text": "John Toda, right?"},
		{"speaker": "John Toda", "text": "Uh... Yes. Do I know you?"},
		{"speaker": "Elena", "text": "Oh, it really is you! My, you've grown so much."},
		{"speaker": "John Toda", "text": "Sorry, but..."},
		{"speaker": "Elena", "text": "Ah, forgive me. I'm Elena. I used to be a teacher around here.", "introduces_speaker": true},
		{"speaker": "John Toda", "text": "Oh..."},
		{"speaker": "Elena", "text": "I knew your father, Juan. It's been quite a long time since I last saw him."},
		{"speaker": "John Toda", "text": "I see."},
		{"speaker": "Elena", "text": "How is he doing these days? Is he well?"},
	], [
		{"speaker": "John Toda", "text": "He's dead."},
		{"speaker": "Elena", "text": "Oh..."},
		{"speaker": "Elena", "text": "I... I didn't know. I'm so sorry."},
		{"speaker": "John Toda", "text": "It's fine."},
		{"speaker": "Elena", "text": "If you don't mind me asking, when did he..."},
		{"speaker": "John Toda", "text": "A while ago."},
		{"speaker": "Elena", "text": "I see..."},
		{"text": "The rest of the ride passes in silence."},
		{"speaker": "Elena", "text": "Ah, this is my stop."},
		{"speaker": "John Toda", "text": "Alright."},
		{"speaker": "Elena", "text": "Thank you for the ride, John."},
		{"speaker": "John Toda", "text": "You're welcome."},
		{"text": "She pays the fare and steps out of the tricycle."},
	], [
		{"speaker": "John Toda", "text": "I don't know."},
		{"speaker": "Elena", "text": "Oh? How come?"},
		{"speaker": "John Toda", "text": "I haven't seen him in a long time either."},
		{"speaker": "Elena", "text": "Oh, I see..."},
		{"speaker": "Elena", "text": "Well, I hope he's doing alright."},
		{"speaker": "John Toda", "text": "Yeah."},
		{"text": "The conversation ends there, and I continue driving."},
		{"speaker": "Elena", "text": "Ah, this is my stop."},
		{"speaker": "John Toda", "text": "Alright."},
		{"speaker": "Elena", "text": "Thank you for the ride, John."},
		{"speaker": "John Toda", "text": "You're welcome."},
		{"text": "She pays the fare and steps out of the tricycle."},
	], "Tell the truth", "Lie")


static func build_scene(introduction: Array, truth: Array, lie: Array, truth_label: String, lie_label: String) -> Dictionary:
	var composition: Array = introduction.duplicate(true)
	var choice_index := composition.size() - 1
	var truth_index := composition.size()
	composition.append_array(truth.duplicate(true))
	var lie_index := composition.size()
	composition.append_array(lie.duplicate(true))
	composition[choice_index]["choices"] = [
		{"text": truth_label, "next_index": truth_index},
		{"text": lie_label, "next_index": lie_index},
	]
	for branch: Dictionary in [
		{"start": truth_index, "end": lie_index - 1, "answer": "truth", "achievement": "tapat"},
		{"start": lie_index, "end": composition.size() - 1, "answer": "lie", "achievement": "sinungaling"},
	]:
		composition[branch.start]["actions"] = [
			{"type": "set_event_value", "id": "elena_old_acquaintance_answer", "value": branch.answer},
			{"type": "unlock_achievement", "id": branch.achievement},
		]
		composition[branch.end]["actions"] = [
			{"type": "set_event_value", "id": "elena_old_acquaintance_seen", "value": true},
		]
		composition[branch.end]["next_index"] = composition.size()
	composition[truth_index]["actions"].push_front({"type": "stop_music", "fade_out": 0.0})
	# Declare the lie branch's music state so save/resume skips the truth branch's
	# stop cue. During normal play, restart=false keeps the existing track going.
	composition[lie_index]["actions"].push_front(CHILL_MUSIC.duplicate(true))
	# Keep the introduction consistent during normal play, replay and resume,
	# independently of the ride counter used by passenger selection.
	var introduced := false
	for line: Dictionary in composition:
		if str(line.get("speaker", "")) == "Elena":
			line["speaker_display_name"] = "Elena" if introduced else "???"
		if bool(line.get("introduces_speaker", false)):
			introduced = true
	return {
		"story_id": "elena_old_acquaintance",
		"chapter_title": "An Old Acquaintance",
		"speaker_portraits": true,
		"background": "res://assets/story/backgrounds/roads/bg1_loop.png",
		"music": CHILL_MUSIC.duplicate(true),
		"ambient_sfx": {
			"path": "res://assets/audio/sfx/driving/engine_loop.mp3",
			"loop": true,
			"volume_db": -12.0,
		},
		"composition": composition,
	}
