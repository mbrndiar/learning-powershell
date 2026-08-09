from __future__ import annotations

import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
ROOT = SKILL_DIR.parents[2]
sys.path.insert(0, str(SKILL_DIR / "scripts"))
import course_adapter  # noqa: E402


class CourseAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = course_adapter.load_manifest()

    def test_committed_manifest_validates(self) -> None:
        projection = course_adapter.validate_manifest(copy.deepcopy(self.manifest), ROOT)
        self.assertEqual(len(projection["concepts"]), len(self.manifest["objectives"]))

    def test_projection_is_deterministic_and_topological(self) -> None:
        first = course_adapter.validate_manifest(copy.deepcopy(self.manifest), ROOT)
        second = course_adapter.validate_manifest(copy.deepcopy(self.manifest), ROOT)
        self.assertEqual(course_adapter.compact(first), course_adapter.compact(second))
        seen: set[str] = set()
        for concept in first["concepts"]:
            self.assertTrue(set(concept["prerequisites"]) <= seen)
            seen.add(concept["id"])

    def test_duplicate_id_fails_closed(self) -> None:
        broken = copy.deepcopy(self.manifest)
        broken["objectives"][1]["id"] = broken["objectives"][0]["id"]
        with self.assertRaises(course_adapter.ManifestError):
            course_adapter.validate_manifest(broken, ROOT)

    def test_unknown_prerequisite_fails_closed(self) -> None:
        broken = copy.deepcopy(self.manifest)
        broken["objectives"][0]["prerequisites"] = ["module.missing"]
        with self.assertRaises(course_adapter.ManifestError):
            course_adapter.validate_manifest(broken, ROOT)

    def test_cycle_fails_closed(self) -> None:
        broken = copy.deepcopy(self.manifest)
        first, second = broken["objectives"][:2]
        first["prerequisites"] = [second["id"]]
        second["prerequisites"] = [first["id"]]
        with self.assertRaises(course_adapter.ManifestError):
            course_adapter.validate_manifest(broken, ROOT)

    def test_missing_path_fails_closed(self) -> None:
        broken = copy.deepcopy(self.manifest)
        broken["objectives"][0]["practice"] = "does/not/exist"
        with self.assertRaises(course_adapter.ManifestError):
            course_adapter.validate_manifest(broken, ROOT)

    def test_missing_learner_selector_fails_closed(self) -> None:
        broken = copy.deepcopy(self.manifest)
        broken["objectives"][-1]["check"] = ["python3", "-V"]
        with self.assertRaises(course_adapter.ManifestError):
            course_adapter.validate_manifest(broken, ROOT)

    def test_protocol_operations_emit_json(self) -> None:
        command = [sys.executable, str(SKILL_DIR / "scripts/course_adapter.py")]
        validated = subprocess.run(command + ["validate"], cwd=ROOT, text=True, capture_output=True, check=True)
        projected = subprocess.run(command + ["state-projection"], cwd=ROOT, text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(validated.stdout)["status"], "valid")
        self.assertIn("concepts", json.loads(projected.stdout))


if __name__ == "__main__":
    unittest.main()
