# QuickNote

A tiny Mac menu-bar app for capturing thoughts and to-dos without opening Notes.
Press a hotkey, type or talk, hit Return, and the text is added as a bullet at the bottom of an Apple Notes page you choose.

| Hotkey | What it does |
|---|---|
| **⌃⌥Space** | Open the capture box to type |
| **⌃⌥D** | Open the capture box and start listening |
| **⌘D** (in the box) | Start/stop dictation |
| **Return** | Save to Notes |
| **Esc** | Cancel |

The menu bar icon (✎) lets you **choose which note** captures go to, create a new note, open the note in Notes, and turn on **Launch at Login**.
If you haven't picked a note yet, the first capture creates one called "Quick Capture".

## Build & run

Requires macOS 13+ and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh
cp -R build/QuickNote.app /Applications/
open /Applications/QuickNote.app
```

## Permissions (first run)

macOS will ask for a few permissions the first time you use each feature:

- **Notes (Automation)** — on your first save. Click OK.
- **Speech Recognition** and **Microphone** — the first time you dictate. The box may close while the prompt is up; just press the hotkey again.

If you denied one by accident, turn it back on in **System Settings → Privacy & Security** (Automation, Microphone, Speech Recognition).

Because the app is self-signed, rebuilding it can make macOS ask for these permissions again.

## Notes

- Use a dedicated note for captures. QuickNote rewrites the note's text to append to it, so images or attachments in that note may be dropped.
- If saving fails, your text is copied to the clipboard so nothing is lost.
