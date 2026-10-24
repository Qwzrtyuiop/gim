"""Run Godot regressions in a copy whose user:// paths cannot touch player saves."""
import argparse
from pathlib import Path
import shutil
import subprocess


def copy_project_sources(root: Path, fixture: Path) -> None:
    """Replace the mirrored sources so removed files cannot hide broken imports."""
    project_root = root.resolve()
    expected = project_root / ".godot" / "refactor_checks"
    if fixture.resolve() != expected:
        raise ValueError("Regression fixture must stay inside the project's .godot/refactor_checks")
    for folder in ("scripts", "scenes", "assets", "tests"):
        destination = fixture / folder
        if not destination.resolve().is_relative_to(expected):
            raise ValueError(f"Fixture source directory escapes the fixture: {destination}")
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(root / folder, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Path to the Godot console executable")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    fixture = root / ".godot" / "refactor_checks"
    fixture.mkdir(parents=True, exist_ok=True)
    copy_project_sources(root, fixture)
    for source in root.glob("icon.svg*"):
        shutil.copy2(source, fixture / source.name)
    imported = root / ".godot" / "imported"
    if not imported.is_dir():
        raise SystemExit("Open the game project in Godot once to import its assets, then rerun.")
    shutil.copytree(imported, fixture / ".godot" / "imported", dirs_exist_ok=True)
    for name in ("global_script_class_cache.cfg", "uid_cache.bin"):
        source = root / ".godot" / name
        if source.exists():
            shutil.copy2(source, fixture / ".godot" / name)
    (fixture / "test_user").mkdir(exist_ok=True)
    for script in (fixture / "scripts").rglob("*.gd"):
        script.write_text(script.read_text(encoding="utf-8-sig").replace("user://", "res://test_user/"), encoding="utf-8")
    codec = fixture / "scripts/save/player_state_save_codec.gd"
    marker = "static func save_to_path(player_state, save_path: String, save_version: int) -> void:"
    codec.write_text(codec.read_text(encoding="utf-8").replace(marker, marker + '\n\tplayer_state.set_meta("test_save_count", int(player_state.get_meta("test_save_count", 0)) + 1)'), encoding="utf-8")
    config = (root / "project.godot").read_text(encoding="utf-8")
    # Existing behavior checks run instant text; dedicated playback checks turn it on.
    config += "\n[testing]\nisolated=true\ninstant_story_text=true\n"
    (fixture / "project.godot").write_text(config, encoding="utf-8")
    result = subprocess.run(
        [args.godot, "--headless", "--rendering-method", "gl_compatibility", "--path", str(fixture), "res://tests/refactor_regression.tscn", "--quit-after", "6000", "--log-file", str(fixture / "checks.log")],
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90,
    )
    output = result.stdout + result.stderr
    print(output)
    unexpected_errors = [
        line for line in output.splitlines()
        if line.startswith("ERROR:") and line != "ERROR: Failed to read the root certificate store."
    ]
    if result.returncode or unexpected_errors or "SCRIPT ERROR" in output or "PASS: all refactor regression checks" not in output:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
