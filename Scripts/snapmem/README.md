# Snapchat Memory Downloader

Recently, Snapchat introduced a **5GB limit on Memories**, so if you want a complete backup of all your memories, you need to download your data manually. This Python script helps you download all your Snapchat memories from a JSON export.

As seen on: https://www.tiktok.com/@giraintech/video/7583879890265558280

---

## Getting Your Snapchat Data
1. Open Snapchat and go to Settings → My Data.
2. Request your Memories and select JSON formatting.
3. Snapchat will email you a link to download a ZIP file containing your exported data.
4. Extract the ZIP file and locate the JSON file to use with this script.

## How It Works

1. Export your Snapchat memories as a JSON file from Snapchat.
2. Run the script, passing the JSON file and an output directory (or omit both to pick them interactively via the built-in TUI):

```bash
uv run snap-mem.py --json memories_history.json --out ./memories
```

> **Tip for macOS users:** If you want to save directly to an external drive, use the path format `/Volumes/Name_of_Drive`.

## Requirements
- [uv](https://docs.astral.sh/uv/) — the script declares its own dependencies (`windows-curses` on Windows, `exif`) via inline PEP 723 metadata, so `uv run` resolves them automatically, no separate install step
- Python 3.13+
- Internet connection (to download media files)
- Access to the JSON export from Snapchat

## Optional: EXIF Geotagging

Pass `--exif` to embed the original capture timestamp and GPS coordinates (when Snapchat recorded a location) into downloaded JPEG EXIF data:

```bash
uv run snap-mem.py --json memories_history.json --out ./memories --exif
```

## Troubleshooting
### ❌ HTTP Error 403: Forbidden

This is normal and expected.

Snapchat download links expire after some time and can only be used a limited number of times so if you are running this program a bit after downloading the json. You might need to re-export a new json from Snapchat. Re-run the code and use the new memories_history.json
