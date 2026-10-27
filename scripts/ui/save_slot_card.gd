extends RefCounted

# A slot's visual content; selection, focus and save operations belong to the screen.
const NotebookTheme := preload("res://scripts/ui/save_notebook_theme.gd")


static func build(slot: int, entry: Dictionary, mode: String, can_save: bool, preview: Texture2D) -> Button:
	var exists := bool(entry.get("exists", false))
	var valid := bool(entry.get("valid", exists))
	var button := Button.new()
	button.name = "Slot%d" % slot
	button.custom_minimum_size = Vector2(0, 136)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = (mode == "save" and (slot == 1 or not can_save)) or (mode == "load" and not valid)
	NotebookTheme.style_button(button)
	var title := "SLOT %02d" % slot
	if slot == 1:
		title += " / AUTOSAVE"
	if exists:
		var image := TextureRect.new()
		image.texture = preview
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		image.position = Vector2(14, 20)
		image.size = Vector2(132, 96)
		image.clip_contents = true
		NotebookTheme.row_label(button, title, 12, 25, 19, NotebookTheme.RED_INK)
		if valid:
			NotebookTheme.row_label(button, "Day %d / %s" % [int(entry.get("day", 1)), str(entry.get("phase", "morning")).capitalize()], 43, 31, 25, NotebookTheme.INK)
			NotebookTheme.row_label(button, str(entry.get("location", "")), 77, 25, 21, NotebookTheme.MUTED)
			NotebookTheme.row_label(button, str(entry.get("saved_at", "")), 106, 23, 18, NotebookTheme.MUTED)
		else:
			NotebookTheme.row_label(button, "Save unavailable", 48, 32, 24, NotebookTheme.INK)
			NotebookTheme.row_label(button, "Click to replace" if mode == "save" and slot != 1 else "Cannot load this file", 93, 27, 20, NotebookTheme.MUTED)
	else:
		NotebookTheme.label(button, "+" if slot != 1 else "AUTO", Rect2(14, 22, 132, 90), 58 if slot != 1 else 26, NotebookTheme.MUTED)
		NotebookTheme.row_label(button, title, 14, 27, 19, NotebookTheme.RED_INK)
		NotebookTheme.row_label(button, "Empty slot", 49, 35, 28, NotebookTheme.INK)
		NotebookTheme.row_label(button, "A new place in your story" if slot != 1 else "Saved when a new day begins", 94, 27, 19, NotebookTheme.MUTED)
	return button
