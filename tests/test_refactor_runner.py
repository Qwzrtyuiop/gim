"""Checks for fixture isolation and stale-source removal; no Godot dependency."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from run_refactor_checks import copy_project_sources


class FixtureCopyTests(unittest.TestCase):
    def test_deleted_sources_disappear_without_removing_cache_or_saved_fixture_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture = root / ".godot" / "refactor_checks"
            for folder in ("scripts", "scenes", "assets", "tests"):
                (root / folder).mkdir()
                (root / folder / "current.txt").write_text("current", encoding="utf-8")
                (fixture / folder).mkdir(parents=True)
                (fixture / folder / "removed.gd").write_text("obsolete", encoding="utf-8")
            imported = fixture / ".godot" / "imported"
            imported.mkdir(parents=True)
            (imported / "cached_texture").write_text("cached", encoding="utf-8")
            saved_data = fixture / "test_user"
            saved_data.mkdir()
            (saved_data / "settings.cfg").write_text("fixture only", encoding="utf-8")

            copy_project_sources(root, fixture)

            for folder in ("scripts", "scenes", "assets", "tests"):
                self.assertFalse((fixture / folder / "removed.gd").exists())
                self.assertEqual((fixture / folder / "current.txt").read_text(encoding="utf-8"), "current")
            self.assertTrue((imported / "cached_texture").exists())
            self.assertTrue((saved_data / "settings.cfg").exists())

    def test_rejects_other_destinations_before_changing_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for destination in (root, root / "unrelated", root.parent / "outside_fixture"):
                with self.subTest(destination=destination):
                    with self.assertRaises(ValueError):
                        copy_project_sources(root, destination)

    def test_rejects_fixture_root_alias_before_copying_or_deleting(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            fixture = root / ".godot" / "refactor_checks"
            original_resolve = Path.resolve

            def resolve_alias(path, *args, **kwargs):
                # Model a symlink/junction without requiring Windows link privileges.
                return root if path == fixture else original_resolve(path, *args, **kwargs)

            with patch.object(Path, "resolve", resolve_alias), \
                    patch("run_refactor_checks.shutil.rmtree") as remove, \
                    patch("run_refactor_checks.shutil.copytree") as copy:
                with self.assertRaises(ValueError):
                    copy_project_sources(root, fixture)
                remove.assert_not_called()
                copy.assert_not_called()


if __name__ == "__main__":
    unittest.main()
