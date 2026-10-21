// UI smoke test run in CI: launches Jot, presses its hotkey, and checks the
// capture box really appears on screen — twice, since reopening is where it broke.
import AppKit
import ApplicationServices

let option: CGEventFlags = [.maskAlternate]
let space: CGKeyCode = 49, escape: CGKeyCode = 53

func press(_ key: CGKeyCode, _ flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
        usleep(50_000)
    }
}

func type(_ text: String) {
    for chunk in text.map(String.init) {
        let units = Array(chunk.utf16)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.post(tap: .cghidEventTap)
        }
        usleep(5_000)
    }
}

/// Height of Jot's on-screen capture box (the window wider than the menu bar icon), or nil.
func boxHeight() -> CGFloat? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for info in windows where info[kCGWindowOwnerName as String] as? String == "Jot" {
        if let bounds = info[kCGWindowBounds as String] as? [String: CGFloat], (bounds["Width"] ?? 0) >= 400 {
            return bounds["Height"]
        }
    }
    return nil
}

func boxVisible() -> Bool { boxHeight() != nil }

func waitFor(_ expected: Bool, _ what: String) -> Bool {
    for _ in 0..<30 {
        if boxVisible() == expected { print("ok: \(what)"); return true }
        usleep(100_000)
    }
    print("FAIL: \(what)")
    return false
}

print("Accessibility trusted (needed to post key events): \(AXIsProcessTrusted())")
var passed = waitFor(false, "box hidden at launch")
for round in 1...2 {
    press(space, option)
    passed = waitFor(true, "⌥Space opens the box (round \(round))") && passed
    if round == 1, let before = boxHeight() {
        type(String(repeating: "a longer thought that wraps onto more lines ", count: 6))
        usleep(500_000)
        let after = boxHeight() ?? 0
        let grew = after > before + 40
        print("\(grew ? "ok" : "FAIL"): box grows with long text (\(Int(before))pt -> \(Int(after))pt)")
        passed = grew && passed
    }
    press(escape)
    passed = waitFor(false, "Esc closes the box (round \(round))") && passed
}
exit(passed ? 0 : 1)
