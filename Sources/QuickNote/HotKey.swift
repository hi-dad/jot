import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.quicknote.app", category: "hotkey")

/// A system-wide keyboard shortcut. Uses the Carbon hot key API, which works
/// from any app and does not need the Accessibility permission.
final class HotKey {
    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    let name: String
    /// Result of registering with the system; anything but `noErr` means the hotkey won't fire.
    private(set) var status: OSStatus = noErr
    private var ref: EventHotKeyRef?
    private let id: UInt32

    /// `keyCode` is a `kVK_…` constant; `modifiers` combines `controlKey`, `optionKey`, `cmdKey`, `shiftKey`.
    init(name: String, keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.name = name
        HotKey.installHandlerIfNeeded()
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.actions[id] = action
        let hotKeyID = EventHotKeyID(signature: OSType(0x514E_4F54), id: id) // "QNOT"
        status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        log.notice("Registered \(name, privacy: .public): status \(self.status)")
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.actions[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let pressed = hotKeyID.id
            log.notice("Hotkey \(pressed) pressed")
            Task { @MainActor in HotKey.actions[pressed]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
