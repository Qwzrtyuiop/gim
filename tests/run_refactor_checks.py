"""Run Godot regressions in a copy whose user:// paths cannot touch player saves."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
from time import perf_counter

from refactor_fixture import sync_fixture_tree


def copy_project_sources(root: Path, fixture: Path) -> None:
    """Refresh sources and sync assets without retaining deleted source files."""
    project_root = root.resolve()
    expected = project_root / ".godot" / "refactor_checks"
    if fixture.resolve() != expected:
        raise ValueError("Regression fixture must stay inside the project's .godot/refactor_checks")
    for folder in ("scripts", "scenes", "assets", "tests"):
        destination = fixture / folder
        if not destination.resolve().is_relative_to(expected):
            raise ValueError(f"Fixture source directory escapes the fixture: {destination}")
        if folder == "assets":
            sync_fixture_tree(root / folder, destination, expected)
        else:
            if destination.exists():
                shutil.rmtree(destination)
            shutil.copytree(root / folder, destination)


def available_checks(root: Path) -> list[str]:
    """Discover built-in cases and standalone modules without launching Godot."""
    regression = (root / "tests/refactor_regression.gd").read_text(encoding="utf-8-sig")
    names = set(re.findall(r"^func _test_([a-z0-9_]+)\(\) -> void:", regression, re.MULTILINE))
    for script in (root / "tests").glob("*_checks.gd"):
        if re.search(r"^static func run\(", script.read_text(encoding="utf-8-sig"), re.MULTILINE):
            names.add(script.stem.removesuffix("_checks"))
    return sorted(names)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the Godot console executable")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--check", action="append", default=[], metavar="NAME", help="Run one focused check; repeat to select more")
    selection.add_argument("--full", action="store_true", help="Explicitly run the entire regression suite")
    parser.add_argument("--list", action="store_true", help="List available focused checks without copying or running anything")
    parser.add_argument("--timeout", type=float, help="Godot timeout in seconds (default: 30 focused, 240 full)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    names = available_checks(root)
    if args.list:
        print("\n".join(names))
        return
    if not args.check and not args.full:
        parser.error("Choose --check NAME (see --list), or explicitly request --full.")
    unknown = set(args.check) - set(names)
    if unknown:
        parser.error("Unknown check(s): " + ", ".join(sorted(unknown)) + ". Use --list.")
    if not args.godot:
        parser.error("--godot is required to run checks.")
    if args.timeout is not None and args.timeout <= 0:
        parser.error("--timeout must be positive.")
    selected = list(dict.fromkeys(args.check))
    timeout = args.timeout if args.timeout is not None else (240 if args.full else 30)
    started = perf_counter()
    print("Preparing isolated fixture for " + ("full suite" if args.full else ", ".join(selected)), flush=True)
    fixture = root / ".godot" / "refactor_checks"
    fixture.mkdir(parents=True, exist_ok=True)
    copy_project_sources(root, fixture)
    for source in root.glob("icon.svg*"):
        shutil.copy2(source, fixture / source.name)
    imported = root / ".godot" / "imported"
    if not imported.is_dir():
        raise SystemExit("Open the game project in Godot once to import its assets, then rerun.")
    sync_fixture_tree(imported, fixture / ".godot" / "imported", fixture)
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
    config += "\n[testing]\nisolated=true\ninstant_story_text=true\nchecks=" + json.dumps(selected) + "\n"
    (fixture / "project.godot").write_text(config, encoding="utf-8")
    print(f"Fixture ready in {perf_counter() - started:.1f}s; running Godot (timeout {timeout:g}s).", flush=True)
    run_started = perf_counter()
    try:
        result = subprocess.run(
            [args.godot, "--headless", "--rendering-method", "gl_compatibility", "--path", str(fixture), "res://tests/refactor_regression.tscn", "--quit-after", "24000", "--log-file", str(fixture / "checks.log")],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        for output in (error.stdout, error.stderr):
            if output:
                print(output.decode("utf-8", errors="replace") if isinstance(output, bytes) else output)
        raise SystemExit(f"Checks timed out after {timeout:g}s. Use --check NAME to narrow the run or --timeout SECONDS if needed.") from error
    output = result.stdout + result.stderr
    print(output)
    print(f"Godot: {perf_counter() - run_started:.1f}s; total: {perf_counter() - started:.1f}s.")
    unexpected_errors = [
        line for line in output.splitlines()
        if line.startswith("ERROR:") and line != "ERROR: Failed to read the root certificate store."
    ]
    pass_marker = "PASS: all refactor regression checks" if args.full else "PASS: selected refactor regression checks"
    if result.returncode or unexpected_errors or "SCRIPT ERROR" in output or pass_marker not in output:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
