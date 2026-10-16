// UI smoke test run in CI: launches Jot, presses its hotkey, and checks the
// capture box really appears on screen — twice, since reopening is where it broke.
import AppKit
import ApplicationServices

let control: CGEventFlags = [.maskControl, .maskAlternate]
let space: CGKeyCode = 49, escape: CGKeyCode = 53

func press(_ key: CGKeyCode, _ flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
        usleep(50_000)
    }
}

/// True if Jot has an on-screen window the size of the capture box (not the menu bar icon).
func boxVisible() -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.contains { info in
        guard info[kCGWindowOwnerName as String] as? String == "Jot",
              let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
        return (bounds["Width"] ?? 0) >= 400
    }
}

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
    press(space, control)
    passed = waitFor(true, "⌃⌥Space opens the box (round \(round))") && passed
    press(escape)
    passed = waitFor(false, "Esc closes the box (round \(round))") && passed
}
exit(passed ? 0 : 1)
