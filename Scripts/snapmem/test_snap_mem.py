import unittest
import importlib.util
import json
import sys
import tempfile
import threading
import zipfile
from datetime import datetime, timezone
from pathlib import Path

# Import snap-mem.py using importlib because of the hyphen in the filename
path = Path(__file__).parent / "snap-mem.py"
spec = importlib.util.spec_from_file_location("snap_mem", path)
assert spec is not None
assert spec.loader is not None
snap_mem = importlib.util.module_from_spec(spec)
sys.modules["snap_mem"] = snap_mem
spec.loader.exec_module(snap_mem)


class TestSnapMem(unittest.TestCase):
    def test_build_base_name_valid(self):
        # Format: %Y-%m-%d %H:%M:%S UTC
        date_str = "2023-01-01 12:00:00 UTC"
        expected = "2023-01-01_12-00-00"
        self.assertEqual(snap_mem.build_base_name(date_str), expected)

    def test_build_base_name_leap_year(self):
        date_str = "2024-02-29 23:59:59 UTC"
        expected = "2024-02-29_23-59-59"
        self.assertEqual(snap_mem.build_base_name(date_str), expected)

    def test_build_base_name_year_boundary(self):
        date_str = "9999-12-31 23:59:59 UTC"
        expected = "9999-12-31_23-59-59"
        self.assertEqual(snap_mem.build_base_name(date_str), expected)

    def test_build_base_name_invalid_format(self):
        # Wrong format
        date_str = "2023/01/01 12:00:00 UTC"
        with self.assertRaises(ValueError):
            snap_mem.build_base_name(date_str)

    def test_build_base_name_empty(self):
        with self.assertRaises(ValueError):
            snap_mem.build_base_name("")

    def test_build_base_name_whitespace(self):
        # build_base_name uses datetime.strptime(date_str, DATE_FMT)
        # strptime is strict about whitespace unless included in fmt
        date_str = " 2023-01-01 12:00:00 UTC "
        with self.assertRaises(ValueError):
            snap_mem.build_base_name(date_str)

    def test_build_base_name_logical_invalid_date(self):
        # 2023 is not a leap year
        date_str = "2023-02-29 12:00:00 UTC"
        with self.assertRaises(ValueError):
            snap_mem.build_base_name(date_str)

    def test_make_unique_name(self):
        # make_unique_name updates the 'existing' set in-place
        existing = {"base.jpg", "base_1.jpg"}
        lock = threading.Lock()

        # base.jpg is in existing. n=1 -> base_1.jpg (in existing). n=2 -> base_2.jpg.
        name = snap_mem.make_unique_name("base", ".jpg", existing, lock)
        self.assertEqual(name, "base_2.jpg")
        self.assertIn("base_2.jpg", existing)

        # base_3.jpg
        name2 = snap_mem.make_unique_name("base", ".jpg", existing, lock)
        self.assertEqual(name2, "base_3.jpg")
        self.assertIn("base_3.jpg", existing)

    def test_make_unique_name_empty_set(self):
        existing = set()
        lock = threading.Lock()
        name = snap_mem.make_unique_name("base", ".jpg", existing, lock)
        self.assertEqual(name, "base.jpg")
        self.assertIn("base.jpg", existing)

    def test_make_unique_name_multiple_collisions(self):
        existing = {"base.jpg", "base_1.jpg", "base_2.jpg", "base_3.jpg"}
        lock = threading.Lock()
        name = snap_mem.make_unique_name("base", ".jpg", existing, lock)
        self.assertEqual(name, "base_4.jpg")
        self.assertIn("base_4.jpg", existing)

    def test_parse_capture_epoch_is_utc(self):
        # date_str carries no real tzinfo for strptime ("UTC" is a literal string match),
        # so a naive .timestamp() would silently use local time instead of UTC.
        date_str = "2023-01-01 12:00:00 UTC"
        expected = datetime(2023, 1, 1, 12, 0, 0, tzinfo=timezone.utc).timestamp()
        self.assertEqual(snap_mem.parse_capture_epoch(date_str), expected)

    def test_extract_zip_atomically_sets_mtime(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            out_dir = Path(tmpdir)
            zip_path = out_dir / "test_memory.zip"
            with zipfile.ZipFile(zip_path, "w") as zf:
                zf.writestr("photo.jpg", b"fake-jpg-bytes")

            capture_epoch = 1672574400.0  # 2023-01-01 12:00:00 UTC
            extracted = snap_mem.extract_zip_atomically(
                zip_path, "2023-01-01_12-00-00", out_dir, set(), threading.Lock(), capture_epoch
            )

            self.assertEqual(len(extracted), 1)
            mtime = (out_dir / extracted[0]).stat().st_mtime
            self.assertAlmostEqual(mtime, capture_epoch, delta=2)

    def test_format_progress_line_video(self):
        line = snap_mem.format_progress_line(
            3, 10, "2023-01-01_12-00-00", "2023-01-01 12:00:00 UTC", True
        )
        self.assertEqual(line, "[3/10] VIDEO 2023-01-01_12-00-00 (12:00:00 UTC)")

    def test_format_progress_line_photo(self):
        line = snap_mem.format_progress_line(
            1, 1, "2023-01-01_12-00-00", "2023-01-01 12:00:00 UTC", False
        )
        self.assertEqual(line, "[1/1] PHOTO 2023-01-01_12-00-00 (12:00:00 UTC)")

    def test_decimal_to_dms(self):
        degrees, minutes, seconds = snap_mem._decimal_to_dms(52.98347)
        self.assertEqual(degrees, 52)
        self.assertEqual(minutes, 59)
        self.assertAlmostEqual(seconds, 0.492, places=2)

    def test_load_items_parses_location(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            json_path = Path(tmpdir) / "memories_history.json"
            json_path.write_text(
                json.dumps(
                    {
                        "Saved Media": [
                            {
                                "Date": "2023-01-01 12:00:00 UTC",
                                "Media Type": "Image",
                                "Media Download Url": "https://example.com/x",
                                "Location": "Latitude, Longitude: 52.98347, -6.9959426",
                            }
                        ]
                    }
                )
            )
            items = snap_mem.load_items(json_path, "all")
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0].latitude, 52.98347)
            self.assertEqual(items[0].longitude, -6.9959426)

    def test_load_items_missing_location_defaults_to_none(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            json_path = Path(tmpdir) / "memories_history.json"
            json_path.write_text(
                json.dumps(
                    {
                        "Saved Media": [
                            {
                                "Date": "2023-01-01 12:00:00 UTC",
                                "Media Type": "Image",
                                "Media Download Url": "https://example.com/x",
                            }
                        ]
                    }
                )
            )
            items = snap_mem.load_items(json_path, "all")
            self.assertEqual(len(items), 1)
            self.assertIsNone(items[0].latitude)
            self.assertIsNone(items[0].longitude)


if __name__ == "__main__":
    unittest.main()
