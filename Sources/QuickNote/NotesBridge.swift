import Foundation

struct NoteRef: Hashable {
    let id: String
    let name: String
    let folder: String
}

struct NotesError: LocalizedError {
    let message: String
    let code: Int

    var errorDescription: String? {
        switch code {
        case -1743:
            return "QuickNote isn't allowed to control Notes. Turn it on in System Settings → Privacy & Security → Automation → QuickNote → Notes."
        case -1728, -1719:
            return "The chosen note couldn't be found. It may have been deleted — pick a note again from the menu bar icon."
        default:
            return "Notes error \(code): \(message)"
        }
    }
}

/// Talks to Apple Notes through AppleScript (Notes has no other public API).
enum NotesBridge {
    private static let fieldSeparator = "\u{1F}"
    private static let recordSeparator = "\u{1E}"

    static func listNotes() throws -> [NoteRef] {
        let output = try run("""
        set fs to character id 31
        set rs to character id 30
        set out to ""
        tell application "Notes"
            repeat with f in folders
                set folderName to name of f
                if folderName is not "Recently Deleted" then
                    set noteIDs to id of every note of f
                    set noteNames to name of every note of f
                    repeat with i from 1 to count of noteIDs
                        set out to out & (item i of noteIDs) & fs & folderName & fs & (item i of noteNames) & rs
                    end repeat
                end if
            end repeat
        end tell
        return out
        """)
        return output.components(separatedBy: recordSeparator).compactMap { record in
            let fields = record.components(separatedBy: fieldSeparator)
            guard fields.count == 3 else { return nil }
            return NoteRef(id: fields[0], name: fields[2], folder: fields[1])
        }
    }

    /// Adds `text` as a new line at the bottom of the note.
    static func append(_ text: String, to noteID: String) throws {
        let html = "<div>" + text.components(separatedBy: .newlines).map(escapeHTML).joined(separator: "<br>") + "</div>"
        _ = try run("""
        tell application "Notes"
            set n to note id "\(escapeAppleScript(noteID))"
            set body of n to (body of n) & "\(escapeAppleScript(html))"
        end tell
        """)
    }

    /// Creates a new note in the default Notes folder and returns it.
    static func createNote(named name: String) throws -> NoteRef {
        let output = try run("""
        set fs to character id 31
        tell application "Notes"
            set acct to default account
            set f to default folder of acct
            set n to make new note at f with properties {body:"<h1>\(escapeAppleScript(escapeHTML(name)))</h1>"}
            return (id of n) & fs & (name of f) & fs & (name of n)
        end tell
        """)
        let fields = output.components(separatedBy: fieldSeparator)
        guard fields.count == 3 else { throw NotesError(message: "Unexpected reply from Notes", code: 0) }
        return NoteRef(id: fields[0], name: fields[2], folder: fields[1])
    }

    /// Opens Notes with the given note selected.
    static func show(_ noteID: String) throws {
        _ = try run("""
        tell application "Notes"
            show note id "\(escapeAppleScript(noteID))"
            activate
        end tell
        """)
    }

    private static func run(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw NotesError(message: "Couldn't build AppleScript", code: 0)
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw NotesError(
                message: errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error",
                code: errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            )
        }
        return result.stringValue ?? ""
    }

    private static func escapeAppleScript(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
