extends RefCounted

# Local character stories keep their return location across VN saves/resumes.
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const STORY_ID := "celina_hospital_introduction"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const RETURN_EVENT := "hospital_story_return_pending"


static func can_start() -> bool:
	return (
		bool(PlayerState.get_event_value("celina_first_encounter_seen", false))
		and not bool(PlayerState.get_event_value("celina_hospital_introduction_seen", false))
		and not bool(PlayerState.get_event_value("celina_hospital_shop_unlocked", false))
		and PlayerState.pending_story.is_empty()
		and not PlayerState.is_run_failed()
	)


static func start() -> bool:
	if not can_start():
		return false
	var payload := PayloadCatalog.build(STORY_ID)
	if payload.is_empty():
		return false
	PlayerState._begin_state_batch()
	PlayerState.set_event_value(RETURN_EVENT, true)
	PlayerState.set_last_seen_story_section(STORY_ID, 0)
	PlayerState.set_pending_story(payload)
	PlayerState.set_resume_scene(STORY_SCENE)
	PlayerState._end_state_batch()
	return true


static func has_pending_return() -> bool:
	return bool(PlayerState.get_event_value(RETURN_EVENT, false))


static func complete_return() -> void:
	PlayerState.set_event_value(RETURN_EVENT, false)
