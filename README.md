# Jot

*Formerly QuickNote.*

A tiny Mac menu-bar app for capturing thoughts and to-dos without opening Notes.
Press a hotkey, type or talk, hit Return, and the text is added as a bullet at the bottom of an Apple Notes page you choose.

| Hotkey | What it does |
|---|---|
| **Hold ⌥ Option** | Open the capture box to type |
| **Hold ⌃ Control** | Open the box and listen while held; release to stop |
| **⌃⌥Space** | Open the capture box to type (backup) |
| **⌃⌥D** | Open the capture box and start listening (backup) |
| **⌘D** (in the box) | Start/stop dictation |
| **Return** | Save to Notes |
| **Esc** | Cancel |

The menu bar icon (✎) lets you **choose which note** captures go to, create a new note, open the note in Notes, and turn on **Launch at Login**.
If you haven't picked a note yet, the first capture creates one called "Quick Capture".

## ⬇️ [Download Jot for Mac](https://github.com/dsryan8197/jot/releases/latest/download/Jot.dmg)

Works on macOS 13 (Ventura) or newer, on both Apple Silicon and Intel Macs.

1. Open the downloaded **Jot.dmg** and drag **Jot** onto the **Applications** folder.
2. Open **Applications** and double-click **Jot**.
3. The first time, your Mac will say it can't verify the app (it isn't from the App Store). Click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Jot. You only need to do this once.

## Build & run

Requires macOS 13+ and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh        # builds, installs to /Applications (replacing the old copy) and relaunches
./build.sh dist   # builds dist/Jot.dmg to share instead
```

Every merge to `main` publishes a new download automatically: GitHub Actions builds the DMG and posts it as the latest release, which is what the download link above serves. Pushes to other branches are built and tested but not published.

## Permissions (first run)

macOS will ask for a few permissions the first time you use each feature:

- **Input Monitoring** — on first launch, for hold ⌥ / hold ⌃. Turn Jot on in the settings page macOS opens, then quit and reopen Jot. (⌃⌥Space and ⌃⌥D work without it.)
- **Notes (Automation)** — on your first save. Click OK.
- **Speech Recognition** and **Microphone** — the first time you dictate. The box may close while the prompt is up; just press the hotkey again.

If you denied one by accident, turn it back on in **System Settings → Privacy & Security** (Input Monitoring, Automation, Microphone, Speech Recognition).

Because the app is self-signed, rebuilding it can make macOS ask for these permissions again.

## Notes

- Use a dedicated note for captures. Jot rewrites the note's text to append to it, so images or attachments in that note may be dropped.
- If saving fails, your text is copied to the clipboard so nothing is lost.
