import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private static let defaultNoteName = "Quick Capture"

    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private let notesMenu = NSMenu()
    private var panel: CapturePanel?
    private var hotKeys: [HotKey] = []
    private let modifierHold = ModifierHold()

    // MARK: Saved note choice

    private var selectedNote: NoteRef? {
        get {
            let defaults = UserDefaults.standard
            guard let id = defaults.string(forKey: "noteID"), let name = defaults.string(forKey: "noteName") else { return nil }
            return NoteRef(id: id, name: name, folder: defaults.string(forKey: "noteFolder") ?? "")
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue?.id, forKey: "noteID")
            defaults.set(newValue?.name, forKey: "noteName")
            defaults.set(newValue?.folder, forKey: "noteFolder")
        }
    }

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusIcon("square.and.pencil")
        statusMenu.delegate = self
        notesMenu.delegate = self
        statusItem.menu = statusMenu

        hotKeys = [
            // ⌃⌥Space: open the box for typing
            HotKey(name: "⌃⌥Space", keyCode: kVK_Space, modifiers: controlKey | optionKey) { [weak self] in
                self?.showCapture(listening: false)
            },
            // ⌃⌥D: open the box and start listening right away
            HotKey(name: "⌃⌥D", keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey) { [weak self] in
                self?.showCapture(listening: true)
            },
        ]

        // Hold ⌥ to open the box; hold ⌃ to talk while it's held.
        modifierHold.onHoldStart = { [weak self] key in
            self?.showCapture(listening: key == .control)
        }
        modifierHold.onHoldEnd = { [weak self] key in
            // Letting go of ⌃ saves what you said, no Return needed.
            if key == .control { self?.panel?.model.finishDictationAndSave() }
        }
        modifierHold.start(askForPermission: true)

        let failed = hotKeys.filter { $0.status != noErr }
        if !failed.isEmpty {
            let list = failed.map { "\($0.name) (error \($0.status))" }.joined(separator: ", ")
            DispatchQueue.main.async { [weak self] in
                self?.showAlert("Some hotkeys didn't register", "\(list). Another app may already be using them. You can still use the menu bar icon.")
            }
        }
    }

    // MARK: Capture box

    private func showCapture(listening: Bool) {
        if let panel {
            bringToFront()
            panel.makeKeyAndOrderFront(nil)
            if listening { panel.model.startDictation() }
            return
        }

        let destination = selectedNote?.name ?? "New note: \(Self.defaultNoteName)"
        let model = CaptureModel(destination: destination)
        model.onSave = { [weak self] text in self?.finishCapture(text) }
        model.onCancel = { [weak self] in self?.closePanel() }

        let panel = CapturePanel(model: model)
        panel.delegate = self
        self.panel = panel
        bringToFront()
        panel.present()
        if listening { model.startDictation() }
    }

    private func closePanel() {
        guard let panel else { return }
        self.panel = nil
        panel.delegate = nil
        panel.model.dictation.stop()
        panel.orderOut(nil)
        NSApp.hide(nil) // hand focus back to the app you were in
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clicking elsewhere dismisses the box, like Spotlight.
        if (notification.object as? NSWindow) === panel {
            panel?.model.cancel()
        }
    }

    private func finishCapture(_ text: String) {
        closePanel()
        guard !text.isEmpty else { return }
        // Let the box disappear before talking to Notes.
        DispatchQueue.main.async { [weak self] in
            self?.save(text)
        }
    }

    private func save(_ text: String) {
        do {
            let note: NoteRef
            if let selected = selectedNote {
                note = selected
            } else {
                note = try NotesBridge.createNote(named: Self.defaultNoteName)
                selectedNote = note
            }
            try NotesBridge.append(text, to: note.id)
            flashSaved()
        } catch {
            // Don't lose the thought: put it on the clipboard.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            showAlert(
                "Couldn't save to Notes",
                "\(error.localizedDescription)\n\nYour text was copied to the clipboard."
            )
        }
    }

    // MARK: Menu bar

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === statusMenu {
            // Picks up Input Monitoring if it was allowed after launch.
            modifierHold.start(askForPermission: false)
            rebuildStatusMenu()
        } else if menu === notesMenu {
            rebuildNotesMenu()
        }
    }

    private func rebuildStatusMenu() {
        statusMenu.removeAllItems()

        let capture = NSMenuItem(title: "New Capture", action: #selector(menuCapture), keyEquivalent: " ")
        capture.keyEquivalentModifierMask = [.control, .option]
        capture.target = self
        statusMenu.addItem(capture)

        let dictate = NSMenuItem(title: "Dictate", action: #selector(menuDictate), keyEquivalent: "d")
        dictate.keyEquivalentModifierMask = [.control, .option]
        dictate.target = self
        statusMenu.addItem(dictate)

        if !modifierHold.isRunning {
            let enable = NSMenuItem(title: "Turn On Hold ⌥ / Hold ⌃…", action: #selector(menuEnableHold), keyEquivalent: "")
            enable.target = self
            statusMenu.addItem(enable)
        }

        statusMenu.addItem(.separator())

        let current = NSMenuItem(title: "Saving to: \(selectedNote?.name ?? "(new “\(Self.defaultNoteName)” note)")", action: nil, keyEquivalent: "")
        current.isEnabled = false
        statusMenu.addItem(current)

        let choose = NSMenuItem(title: "Choose Note", action: nil, keyEquivalent: "")
        choose.submenu = notesMenu
        statusMenu.addItem(choose)

        let create = NSMenuItem(title: "Create New Note…", action: #selector(menuCreateNote), keyEquivalent: "")
        create.target = self
        statusMenu.addItem(create)

        if selectedNote != nil {
            let open = NSMenuItem(title: "Open Note in Notes", action: #selector(menuOpenNote), keyEquivalent: "")
            open.target = self
            statusMenu.addItem(open)
        }

        statusMenu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(menuToggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        statusMenu.addItem(login)

        statusMenu.addItem(NSMenuItem(title: "Quit QuickNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func rebuildNotesMenu() {
        notesMenu.removeAllItems()
        let notes: [NoteRef]
        do {
            notes = try NotesBridge.listNotes()
        } catch {
            let item = NSMenuItem(title: "Couldn't read Notes", action: nil, keyEquivalent: "")
            item.isEnabled = false
            notesMenu.addItem(item)
            let message = error.localizedDescription
            DispatchQueue.main.async { [weak self] in self?.showAlert("Couldn't read your notes", message) }
            return
        }

        if notes.isEmpty {
            let item = NSMenuItem(title: "No notes found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            notesMenu.addItem(item)
            return
        }

        let selectedID = selectedNote?.id
        var lastFolder: String?
        for note in notes {
            if note.folder != lastFolder {
                if lastFolder != nil { notesMenu.addItem(.separator()) }
                let header = NSMenuItem(title: note.folder, action: nil, keyEquivalent: "")
                header.isEnabled = false
                notesMenu.addItem(header)
                lastFolder = note.folder
            }
            let title = note.name.isEmpty ? "(untitled)" : note.name
            let item = NSMenuItem(title: title, action: #selector(menuPickNote(_:)), keyEquivalent: "")
            item.target = self
            item.indentationLevel = 1
            item.representedObject = note
            item.state = note.id == selectedID ? .on : .off
            notesMenu.addItem(item)
        }
    }

    @objc private func menuCapture() { showCapture(listening: false) }

    @objc private func menuDictate() { showCapture(listening: true) }

    @objc private func menuEnableHold() {
        if modifierHold.start(askForPermission: true) { return }
        showAlert(
            "Allow Input Monitoring",
            "To open QuickNote by holding ⌥ (type) or ⌃ (talk), turn on QuickNote in System Settings → Privacy & Security → Input Monitoring, then quit and reopen QuickNote."
        )
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func menuPickNote(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? NoteRef else { return }
        selectedNote = note
    }

    @objc private func menuCreateNote() {
        bringToFront()
        let alert = NSAlert()
        alert.messageText = "New note name"
        alert.informativeText = "QuickNote will create this note in your default Notes folder and save captures to it."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = Self.defaultNoteName
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            selectedNote = try NotesBridge.createNote(named: name)
        } catch {
            showAlert("Couldn't create the note", error.localizedDescription)
        }
    }

    @objc private func menuOpenNote() {
        guard let note = selectedNote else { return }
        do {
            try NotesBridge.show(note.id)
        } catch {
            showAlert("Couldn't open the note", error.localizedDescription)
        }
    }

    @objc private func menuToggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert("Couldn't change Launch at Login", "\(error.localizedDescription)\n\nTip: move QuickNote.app into your Applications folder first.")
        }
    }

    // MARK: Helpers

    /// Shows the app's windows and makes it active. It must un-hide first: closing the
    /// box hides the app, and a hidden app's windows stay invisible even when ordered front.
    private func bringToFront() {
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setStatusIcon(_ symbol: String) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "QuickNote")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    /// Briefly swaps the menu bar icon for a checkmark after a successful save.
    private func flashSaved() {
        setStatusIcon("checkmark.circle.fill")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.setStatusIcon("square.and.pencil")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        bringToFront()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
