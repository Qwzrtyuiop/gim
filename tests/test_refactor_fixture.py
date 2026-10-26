"""Incremental fixture-copy coverage; never starts Godot."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from refactor_fixture import sync_fixture_tree


class IncrementalFixtureTests(unittest.TestCase):
    def test_reuses_unchanged_files_refreshes_changes_and_prunes_removed_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "assets"
            source.mkdir()
            asset = source / "portrait.png"
            asset.write_bytes(b"first")
            fixture = root / ".godot" / "refactor_checks"
            destination = fixture / "assets"
            sync_fixture_tree(source, destination, fixture)
            with patch("refactor_fixture.shutil.copy2") as copy:
                sync_fixture_tree(source, destination, fixture)
                copy.assert_not_called()
            (destination / "removed").mkdir()
            (destination / "removed" / "old.png").write_bytes(b"old")
            asset.write_bytes(b"different contents")
            sync_fixture_tree(source, destination, fixture)
            self.assertFalse((destination / "removed").exists())
            self.assertEqual((destination / asset.name).read_bytes(), asset.read_bytes())
            (destination / asset.name).write_bytes(b"fixture change")
            self.assertEqual(asset.read_bytes(), b"different contents")

    def test_rejects_destination_outside_fixture_before_copying(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "assets"
            source.mkdir()
            fixture = root / ".godot" / "refactor_checks"
            with patch("refactor_fixture.shutil.copy2") as copy:
                with self.assertRaises(ValueError):
                    sync_fixture_tree(source, root / "outside", fixture)
                copy.assert_not_called()

    def test_rejects_escaping_nested_alias_before_mutating_its_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "assets"
            source.mkdir()
            fixture = root / ".godot" / "refactor_checks"
            destination = fixture / "assets"
            destination.mkdir(parents=True)
            alias = destination / "stale"
            alias.mkdir()
            protected = root / "protected"
            protected.mkdir()
            (protected / "keep.txt").write_text("keep", encoding="utf-8")
            original_resolve = Path.resolve

            def resolve_alias(path, *args, **kwargs):
                return protected if path == alias else original_resolve(path, *args, **kwargs)

            with patch.object(Path, "resolve", resolve_alias):
                with self.assertRaises(ValueError):
                    sync_fixture_tree(source, destination, fixture)
            self.assertEqual((protected / "keep.txt").read_text(encoding="utf-8"), "keep")


if __name__ == "__main__":
    unittest.main()
