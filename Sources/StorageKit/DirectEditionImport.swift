import AppKit
import UniformTypeIdentifiers
import SuperNotesCore

/// "Import from Super Notes (direct download)": the Mac App Store edition lives in its own container, so it starts
/// empty. With the user's pick of the direct edition's data folder it COPIES notes (merged, newer edits win),
/// custom extensions, themes and a downloaded model into the container, and with a second pick the shareable
/// settings. The source is only ever read.
public enum DirectEditionImport {
    public struct Summary: Equatable, Sendable {
        public var notes = 0
        public var extensions: [String] = []
        public var themes: [String] = []
        public var models: [String] = []
        public init() {}
        public var text: String {
            var parts = ["\(notes) note\(notes == 1 ? "" : "s")"]
            if !extensions.isEmpty { parts.append("\(extensions.count) extension\(extensions.count == 1 ? "" : "s")") }
            if !themes.isEmpty { parts.append("\(themes.count) theme\(themes.count == 1 ? "" : "s")") }
            if !models.isEmpty { parts.append("the AI model") }
            return parts.joined(separator: ", ")
        }
    }

    /// Copies everything importable from `source` (a direct edition's `Application Support/Super Notes`).
    /// Notes go through a temporary copy of the database, so the direct edition's files are never opened for writing.
    @MainActor
    public static func importData(from source: URL, into store: SQLiteNoteStore,
                                  support: URL = SuperNotesPaths.support) throws -> Summary {
        let fm = FileManager.default
        let database = source.appendingPathComponent("notes.sqlite")
        guard fm.fileExists(atPath: database.path) else {
            throw StorageError(message: "That folder has no Super Notes notes (notes.sqlite).")
        }
        var summary = Summary()
        let scratch = fm.temporaryDirectory.appendingPathComponent("supernotes-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        for suffix in ["", "-wal", "-shm"] {
            let file = source.appendingPathComponent("notes.sqlite" + suffix)
            if fm.fileExists(atPath: file.path) { try fm.copyItem(at: file, to: scratch.appendingPathComponent("notes.sqlite" + suffix)) }
        }
        let exported = try SQLiteNoteStore(url: scratch.appendingPathComponent("notes.sqlite"),
                                           backupsFolder: scratch.appendingPathComponent("Backups")).exportJSON()
        summary.notes = try store.importJSON(exported)

        // Folders of items: anything not already here is copied; nothing here is replaced.
        func copyNew(_ name: String, filter: (URL) -> Bool = { _ in true }) -> [String] {
            let from = source.appendingPathComponent(name, isDirectory: true)
            let to = SuperNotesPaths.ensure(support.appendingPathComponent(name, isDirectory: true))
            let items = (try? fm.contentsOfDirectory(at: from, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            return items.filter(filter).sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { item in
                let target = to.appendingPathComponent(item.lastPathComponent)
                guard !fm.fileExists(atPath: target.path), (try? fm.copyItem(at: item, to: target)) != nil else { return nil }
                return item.lastPathComponent
            }
        }
        summary.extensions = copyNew("Extensions")
        summary.themes = copyNew("Themes")
        // Finished models only (a `.partial` download is re-fetched and verified by AIKit).
        summary.models = copyNew("Models") { $0.pathExtension == "gguf" }
        Log.store.info("imported from the direct edition: \(summary.text, privacy: .public)")
        return summary
    }

    /// Applies the shareable settings (the ones iCloud sync carries) from the direct edition's preferences file.
    /// Per-Mac and privacy switches are left alone. Returns how many settings were set.
    @MainActor
    public static func importPreferences(from plist: URL) throws -> Int {
        guard let values = NSDictionary(contentsOf: plist) as? [String: Any] else {
            throw StorageError(message: "That isn't a preferences file.")
        }
        let names = PreferencesSync.keyNames.filter { values[$0] != nil }.sorted()
        for name in names { Defaults.store.set(values[name], forKey: name) }
        for name in names { Defaults.changes.send(name) }
        return names.count
    }

    #if APP_STORE
    /// The user-initiated flow (Settings → Notes → Import & export).
    @MainActor
    public static func run(into store: SQLiteNoteStore) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = Distribution.directSupportFolder
        panel.prompt = "Import"
        panel.message = "Choose the “Super Notes” folder of the direct-download edition. Its notes, extensions and themes are copied here; the original is left as it is."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let summary = try importData(from: folder, into: store)
            HUD.show("Imported \(summary.text)", kind: .success)
        } catch {
            return Alerts.error("Couldn't import from the direct-download edition.", error)
        }
        guard Alerts.confirm("Import settings too?",
                             info: "Choose the direct edition's preferences file (com.udsy.supernotes.plist) to bring over themes, keywords, shortcuts and other settings.",
                             confirmTitle: "Choose File…", cancelTitle: "Not Now") else { return }
        let prefs = NSOpenPanel()
        prefs.allowedContentTypes = [.propertyList]
        prefs.directoryURL = Distribution.directPreferencesFile.deletingLastPathComponent()
        prefs.message = "Choose com.udsy.supernotes.plist"
        guard prefs.runModal() == .OK, let url = prefs.url else { return }
        do {
            let count = try importPreferences(from: url)
            HUD.show("Imported \(count) setting\(count == 1 ? "" : "s")", kind: .success)
        } catch {
            Alerts.error("Couldn't import the settings.", error)
        }
    }
    #endif
}
