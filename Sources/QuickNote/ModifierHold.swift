import AppKit
import os

private let log = Logger(subsystem: "com.quicknote.app", category: "hold")

/// Detects holding Control or Option on its own, anywhere in the system.
///
/// A hold only counts if the key stays down for `delay` with no other key or mouse
/// button pressed, so ordinary shortcuts (⌃C, ⌥-click, ⌥-letters) never trigger it.
/// Watching keys outside the app needs the Input Monitoring permission.
@MainActor
final class ModifierHold {
    enum Key { case control, option }

    var onHoldStart: (Key) -> Void = { _ in }
    var onHoldEnd: (Key) -> Void = { _ in }

    private let delay: Duration = .milliseconds(400)
    private var tap: CFMachPort?
    private var pending: Task<Void, Never>?
    private var held: Key?

    var isRunning: Bool { tap != nil }

    /// Starts watching. Returns false if Input Monitoring isn't allowed yet; with `askForPermission`
    /// macOS shows its prompt (only the first time).
    @discardableResult
    func start(askForPermission: Bool) -> Bool {
        guard tap == nil else { return true }
        guard CGPreflightListenEventAccess() else {
            if askForPermission { CGRequestListenEventAccess() }
            log.notice("Input Monitoring not allowed; hold shortcuts are off")
            return false
        }

        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                // The tap is on the main run loop, so this runs on the main thread.
                let hold = Unmanaged<ModifierHold>.fromOpaque(info!).takeUnretainedValue()
                let flags = event.flags
                MainActor.assumeIsolated { hold.handle(type, flags) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Couldn't create the event tap")
            return false
        }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.notice("Hold shortcuts on")
        return true
    }

    private func handle(_ type: CGEventType, _ flags: CGEventFlags) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            let down = flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskSecondaryFn])
            let key: Key? = down == .maskControl ? .control : down == .maskAlternate ? .option : nil
            if key == held, key != nil { return }
            cancelPending()
            if let ended = held {
                held = nil
                onHoldEnd(ended)
            }
            if let key { schedule(key) }
        default:
            // Another key or a click while the modifier is down: it's a shortcut, not a hold.
            cancelPending()
        }
    }

    private func schedule(_ key: Key) {
        pending = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.pending = nil
            self.held = key
            log.notice("Hold started: \(key == .control ? "control" : "option", privacy: .public)")
            self.onHoldStart(key)
        }
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}
