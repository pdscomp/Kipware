import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def load_module(relpath, name):
    module_path = ROOT / relpath
    spec = importlib.util.spec_from_file_location(name, module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class FeedLockTest(unittest.TestCase):
    def test_parse_feeds_conf_ignores_comments_and_parses_git_feeds(self):
        feed_lock = load_module("scripts/ci/feed_lock.py", "feed_lock")
        feeds = feed_lock.parse_feeds_conf(
            """
            #src-git disabled https://example.invalid/disabled.git
            src-git packages https://github.com/Entware/entware-packages.git
            src-git-full custom https://example.invalid/custom.git;main
            src-cpy local ../local-feed
            """
        )
        self.assertEqual(
            feeds,
            [
                {
                    "method": "src-git",
                    "name": "packages",
                    "url": "https://github.com/Entware/entware-packages.git",
                    "ref": "HEAD",
                },
                {
                    "method": "src-git-full",
                    "name": "custom",
                    "url": "https://example.invalid/custom.git",
                    "ref": "main",
                },
            ],
        )

    def test_feed_lock_sha_is_stable_and_changes_with_feed_sha(self):
        feed_lock = load_module("scripts/ci/feed_lock.py", "feed_lock")
        lock_a = {
            "schema": 1,
            "feeds": [
                {"method": "src-git", "name": "packages", "url": "u", "ref": "HEAD", "sha": "aaa"}
            ],
        }
        lock_b = {
            "schema": 1,
            "feeds": [
                {"method": "src-git", "name": "packages", "url": "u", "ref": "HEAD", "sha": "bbb"}
            ],
        }
        self.assertEqual(feed_lock.stable_sha256(lock_a), feed_lock.stable_sha256(dict(reversed(lock_a.items()))))
        self.assertNotEqual(feed_lock.stable_sha256(lock_a), feed_lock.stable_sha256(lock_b))


class BuildFingerprintTest(unittest.TestCase):
    def test_build_fingerprint_tracks_global_packaging_inputs_separately(self):
        build_fingerprint = load_module("scripts/ci/build_fingerprint.py", "build_fingerprint")
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            (root / "scripts").mkdir()
            (root / "scripts" / "rstrip.sh").write_text("rstrip v1\n")
            (root / "rules.mk").write_text("rules v1\n")
            (root / "configs").mkdir()
            (root / "configs" / "armv7hf-5.4.config").write_text("CONFIG_PACKAGE_foo=m\n")
            feed_lock = {"schema": 1, "feeds": []}

            fp1 = build_fingerprint.compute_fingerprint(root, feed_lock, branch="main")
            (root / "scripts" / "rstrip.sh").write_text("rstrip v2\n")
            fp2 = build_fingerprint.compute_fingerprint(root, feed_lock, branch="main")

        self.assertNotEqual(fp1["components"]["global_packaging_sha"], fp2["components"]["global_packaging_sha"])
        self.assertEqual(fp1["components"]["package_input_sha"], fp2["components"]["package_input_sha"])
        self.assertNotEqual(fp1["build_fingerprint"], fp2["build_fingerprint"])


class ManifestCompareTest(unittest.TestCase):
    def test_compare_manifest_skips_only_identical_fingerprints(self):
        compare_manifest = load_module("scripts/ci/compare_manifest.py", "compare_manifest")
        current = {
            "build_fingerprint": "sha256:abc",
            "components": {"foundation_sha": "sha256:f1", "global_packaging_sha": "sha256:g1"},
        }
        previous_same = {
            "build_fingerprint": "sha256:abc",
            "components": {"foundation_sha": "sha256:f1", "global_packaging_sha": "sha256:g1"},
        }
        previous_global_old = {
            "build_fingerprint": "sha256:old",
            "components": {"foundation_sha": "sha256:f1", "global_packaging_sha": "sha256:g0"},
        }

        self.assertFalse(compare_manifest.compare_fingerprints(current, previous_same)["needs_build"])
        changed = compare_manifest.compare_fingerprints(current, previous_global_old)
        self.assertTrue(changed["needs_build"])
        self.assertTrue(changed["force_world_rebuild"])
        self.assertIn("global_packaging_sha", changed["changed_components"])


class WriteBuildManifestTest(unittest.TestCase):
    def test_collect_ipk_manifest_and_hashes_packages_files(self):
        write_manifest = load_module("scripts/ci/write_build_manifest.py", "write_build_manifest")
        with tempfile.TemporaryDirectory() as td:
            feed_dir = pathlib.Path(td)
            (feed_dir / "foo_1_armv7-5.4.ipk").write_bytes(b"foo")
            (feed_dir / "Packages").write_text("Package: foo\n")
            (feed_dir / "Packages.gz").write_bytes(b"gz")
            outputs = write_manifest.collect_outputs(feed_dir)

        self.assertEqual(outputs["packages_count"], 1)
        self.assertEqual(outputs["ipks"][0]["filename"], "foo_1_armv7-5.4.ipk")
        self.assertTrue(outputs["packages_sha256"].startswith("sha256:"))
        self.assertTrue(outputs["packages_gz_sha256"].startswith("sha256:"))


if __name__ == "__main__":
    unittest.main()
