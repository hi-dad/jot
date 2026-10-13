import AppKit
import SwiftUI

@MainActor
final class CaptureModel: ObservableObject {
    @Published var text = ""
    @Published var errorMessage: String?
    let dictation = Dictation()
    let destination: String

    var onSave: @MainActor (String) -> Void = { _ in }
    var onCancel: @MainActor () -> Void = {}

    private var textBeforeDictation = ""

    init(destination: String) {
        self.destination = destination
        dictation.onTranscript = { [weak self] transcript in
            guard let self else { return }
            let base = self.textBeforeDictation
            self.text = base.isEmpty ? transcript : base + " " + transcript
        }
        dictation.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    func toggleDictation() {
        dictation.isListening ? stopDictation() : startDictation()
    }

    func startDictation() {
        guard !dictation.isListening else { return }
        textBeforeDictation = text.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        dictation.start()
    }

    func stopDictation() {
        dictation.stop()
    }

    func save() {
        dictation.stop()
        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func cancel() {
        dictation.stop()
        onCancel()
    }
}

struct CaptureView: View {
    @ObservedObject var model: CaptureModel
    @ObservedObject var dictation: Dictation
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField(
                    dictation.isListening ? "Listening…" : "Type a thought, or press ⌘D to talk",
                    text: $model.text,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .lineLimit(1...8)
                .focused($focused)
                .onSubmit { model.save() }

                Button(action: model.toggleDictation) {
                    Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 18))
                        .foregroundStyle(dictation.isListening ? Color.red : Color.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: .command)
                .help("Dictate (⌘D)")
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Label(model.destination, systemImage: "note.text")
                    .lineLimit(1)
                Spacer()
                Text("↩ save    ⌘D talk    esc cancel")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(width: 580)
        // Invisible button so Escape cancels even while typing.
        .background(
            Button("Cancel", action: model.cancel)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
        .onExitCommand(perform: model.cancel)
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }
}

/// The floating Spotlight-style box that appears on the hotkey.
final class CapturePanel: NSPanel {
    let model: CaptureModel

    init(model: CaptureModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 110),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        let host = NSHostingView(rootView: CaptureView(model: model, dictation: model.dictation))
        contentView = host
        setContentSize(host.fittingSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeKey: Bool { true }

    /// Shows the panel near the top of whichever screen the mouse is on.
    func present() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            setFrameOrigin(NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.minY + visible.height * 0.72 - frame.height
            ))
        }
        makeKeyAndOrderFront(nil)
    }
}
