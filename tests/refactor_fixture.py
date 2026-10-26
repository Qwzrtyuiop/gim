"""Refresh large fixture trees without recopying unchanged asset bytes."""
from pathlib import Path
import shutil


def _checked_destination(path: Path, fixture_root: Path) -> None:
    resolved = path.resolve()
    if resolved == fixture_root or not resolved.is_relative_to(fixture_root):
        raise ValueError(f"Fixture destination escapes its tree: {path}")
    if path.is_symlink() or getattr(path, "is_junction", lambda: False)():
        raise ValueError(f"Fixture destination cannot be a link: {path}")


def _remove_destination(path: Path, fixture_root: Path) -> None:
    _checked_destination(path, fixture_root)
    if path.is_dir():
        for child in path.iterdir():
            _remove_destination(child, fixture_root)
        path.rmdir()
    else:
        path.unlink()


def sync_fixture_tree(source: Path, destination: Path, fixture_root: Path) -> None:
    """Mirror a tree inside an already verified fixture; never share file inodes."""
    fixture_base = fixture_root.resolve()
    if fixture_base != fixture_root.absolute():
        raise ValueError("Fixture root must be an absolute, resolved path")
    source = source.resolve()
    if source.is_relative_to(fixture_base):
        raise ValueError("Fixture sources must come from outside the fixture")
    _sync_tree(source, destination, fixture_base)


def _sync_tree(source: Path, destination: Path, fixture_root: Path) -> None:
    _checked_destination(destination, fixture_root)
    if not source.is_dir():
        raise ValueError(f"Fixture source must be a directory: {source}")
    if destination.exists() and not destination.is_dir():
        _remove_destination(destination, fixture_root)
    destination.mkdir(parents=True, exist_ok=True)
    sources = {child.name: child for child in source.iterdir()}
    for child in destination.iterdir():
        if child.name not in sources:
            _remove_destination(child, fixture_root)
    for name, child in sources.items():
        target = destination / name
        _checked_destination(target, fixture_root)
        if child.is_symlink() or getattr(child, "is_junction", lambda: False)():
            raise ValueError(f"Fixture source cannot be a link: {child}")
        if child.is_dir():
            _sync_tree(child, target, fixture_root)
            continue
        if target.is_dir():
            _remove_destination(target, fixture_root)
        source_stat = child.stat()
        if target.exists():
            target_stat = target.stat()
            if (source_stat.st_size, source_stat.st_mtime_ns) == (
                target_stat.st_size, target_stat.st_mtime_ns
            ):
                continue
        shutil.copy2(child, target)
