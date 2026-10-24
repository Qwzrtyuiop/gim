# Gulong agent instructions

## Start here

- Read `docs/PROJECT_CONTEXT.md` for the project map, current handoff, and validation commands.
- Run `git status --short` before editing. This checkout contains substantial in-progress work; preserve existing edits, deletions, and untracked files.
- Read the files relevant to the requested change. `DEVELOPMENT_REFERENCE.md` is a dated audit; verify its findings against current code and the context handoff.

## Project

Gulong (Windows product name: Gulong ng Buhay) is a Godot 4.6 / GDScript 2D tricycle-driving game with branching English/Tagalog stories, fares, fuel, energy, upgrades, and weekly debt. The entry scene is `scenes/main_menu.tscn`; the viewport is 1280x720 with `canvas_items` stretch. There is no package-install or web-build step.

## Implementation contracts

- Keep `scripts/game.gd` as the gameplay coordinator. Extend the relevant helpers in `scripts/game/` and preserve setup/frame-update order and shared `owner` fields.
- Put shared driving, resource, upgrade, and store tuning in `scripts/config/game_tuning.gd`. Traffic profiles belong in `scripts/game/stage_profiles.gd`. Check modifier ordering before changing balance.
- `PlayerState` owns cross-scene state; use its APIs and domain helpers in `scripts/state/`. New persisted fields also need codec/resource fields, defaults, reset behavior, and migration. Save version is currently 4; inspect it before making persistence changes.
- Keep content IDs stable. Story, event, character, achievement, upgrade, and memory IDs are save contracts; display names may differ from IDs (Elena is `ely`).
- Stage descriptors can contain `traffic-jam`; use existing parsing helpers. Current phase can differ from the just-completed result's time.
- Hidden `EditorPreview` nodes in `scenes/main.tscn` provide runtime geometry. Preserve them when editing the scene.
- Register new audio players with `AudioSettingsManager` using the appropriate category.
- Reuse `scripts/ui/tutorial_overlay_helper.gd` for tutorial overlay construction and `scripts/library/library_theme.gd` for library styling. Screen-specific helpers own their content and interaction rules.
- Retain Godot `.uid` files for scripts/resources. Keep generated `.godot/` content and machine-specific editor/export settings out of changes.

## Story changes

- Read `scripts/story/story_payloads_guide.md` and use `scripts/story/payloads/templates/story_payload_template.gd`.
- Author one `build()` with `StoryPayload.normalize(...)`, canonical `composition`, line/choice `actions`, and action `type`. Legacy keys exist for save compatibility.
- Use tabs, one dictionary field per line, trailing commas, numbered section comments, and named jump constants. Preserve existing section indices in each language because saves persist them; append new branches where possible.
- Register builders in `scripts/story/story_payload_catalog.gd`. For new translations, keep branches, conditions, actions, and presentation aligned with the source language. Preserve intentional existing placeholders/fallbacks unless asked to complete them.
- Preserve checkpoint/action-cursor behavior and state batching. Rewards and penalties must execute once across save/resume; gallery replays must suppress persistent effects.
- Read the portrait, random-event, or special-stage guide when touching those systems; links are in the context document.

## Validation and reporting

- For gameplay/story changes, run the existing isolated runner: `python tests/run_refactor_checks.py --godot "<Godot console executable>"`. See the context document for the verified local path and coverage.
- Never launch `tests/refactor_regression.tscn` directly: the suite resets state. The Python runner copies the project and redirects save/settings paths to protect real progress.
- Use disposable saves for manual progression checks. Ordinary game startup can autosave; main-menu reset removes progress.
- Check the final diff for unintended changes and report what changed, what was verified, and any remaining limitations. Documentation-only work needs link/command/diff checks, not a new test suite.
