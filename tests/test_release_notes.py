import importlib.util
import pathlib
import tempfile
import unittest


MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "release" / "generate-release-notes.py"
spec = importlib.util.spec_from_file_location("generate_release_notes", MODULE_PATH)
notes = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(notes)


class ReleaseNotesHelpersTest(unittest.TestCase):
    def test_parse_package_manifest_ignores_comments_and_blanks(self):
        text = """
        # comment
        python3

        wget-ssl
          libopenssl
        """
        self.assertEqual(notes.parse_package_manifest(text), {"python3", "wget-ssl", "libopenssl"})

    def test_parse_config_packages_only_module_packages(self):
        text = """
        CONFIG_PACKAGE_python3=m
        # CONFIG_PACKAGE_foo is not set
        CONFIG_PACKAGE_bar=y
        CONFIG_PACKAGE_wget-ssl=m
        """
        self.assertEqual(notes.parse_config_packages(text), {"python3", "wget-ssl"})

    def test_target_summary_reads_env_configs(self):
        with tempfile.TemporaryDirectory() as td:
            target_dir = pathlib.Path(td)
            (target_dir / "cc-test.env").write_text(
                'TARGET_ID=cc-test\n'
                'TARGET_DISPLAY_NAME="Test Printer"\n'
                'KIP_TARGET=/tmp/kipware-release-test/.kipware\n'
            )
            summary = notes.target_summary(target_dir)
        self.assertIn("Test Printer", summary)
        self.assertIn("cc-test", summary)
        self.assertIn("/tmp/kipware-release-test/.kipware", summary)


if __name__ == "__main__":
    unittest.main()
