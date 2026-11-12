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
        /// Extensions left behind: installed from GitHub in the direct edition (downloaded code), or all of them when
        /// the settings file that tells them apart wasn't given.
        public var skippedExtensions: [String] = []
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
    /// - `modelFileName`: the one model file AIKit uses; it lands as `<name>.partial` so AIKit installs it only after
    ///   its SHA-256 matches (`Services.ai.adoptImportedModel()`). Other files in Models/ are ignored.
    /// - `githubExtensions`: extension folders the direct edition installed from GitHub (its `extensions.sources`
    ///   setting); they are not copied, since this edition doesn't take downloaded code. nil = unknown: no
    ///   extension is copied.
    @MainActor
    public static func importData(from source: URL, into store: SQLiteNoteStore, support: URL = SuperNotesPaths.support,
                                  modelFileName: String?, githubExtensions: Set<String>?) throws -> Summary {
        let fm = FileManager.default
        let database = source.appendingPathComponent("notes.sqlite")
        guard fm.fileExists(atPath: database.path) else {
            throw StorageError(message: "That folder has no Super Notes notes (notes.sqlite).")
        }
        func isSymlink(_ url: URL) -> Bool {
            (try? fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
        }
        var summary = Summary()
        let scratch = fm.temporaryDirectory.appendingPathComponent("supernotes-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        for suffix in ["", "-wal", "-shm"] {
            let file = source.appendingPathComponent("notes.sqlite" + suffix)
            // A link would be copied as a link, and SQLite would then write through it into the source.
            if isSymlink(file) { throw StorageError(message: "notes.sqlite\(suffix) is a link; choose the folder that holds the real file.") }
            if fm.fileExists(atPath: file.path) { try fm.copyItem(at: file, to: scratch.appendingPathComponent("notes.sqlite" + suffix)) }
        }
        let copy = try SQLiteNoteStore(url: scratch.appendingPathComponent("notes.sqlite"),
                                       backupsFolder: scratch.appendingPathComponent("Backups"))
        // A copy taken mid-write (the direct edition still running) can come out damaged; recovering it to an empty
        // store must not look like a successful import of nothing.
        if copy.recovery != nil, copy.deck.isEmpty, copy.archived.isEmpty {
            throw StorageError(message: "The notes database couldn't be read in one piece. Quit the direct-download Super Notes, then import again.")
        }
        summary.notes = try store.importJSON(copy.exportJSON())

        // Folders of items: anything not already here is copied; nothing here is replaced.
        func copyNew(_ name: String, filter: (URL) -> Bool = { _ in true }) -> [String] {
            let from = source.appendingPathComponent(name, isDirectory: true)
            let to = SuperNotesPaths.ensure(support.appendingPathComponent(name, isDirectory: true))
            let items = (try? fm.contentsOfDirectory(at: from, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            return items.filter { !isSymlink($0) && filter($0) }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { item in
                let target = to.appendingPathComponent(item.lastPathComponent)
                guard !fm.fileExists(atPath: target.path), (try? fm.copyItem(at: item, to: target)) != nil else { return nil }
                return item.lastPathComponent
            }
        }
        let extensionFolders = ((try? fm.contentsOfDirectory(at: source.appendingPathComponent("Extensions"), includingPropertiesForKeys: nil,
                                                             options: .skipsHiddenFiles)) ?? []).map(\.lastPathComponent)
        summary.skippedExtensions = extensionFolders.filter { githubExtensions?.contains($0) ?? true }.sorted()
        summary.extensions = copyNew("Extensions") { !summary.skippedExtensions.contains($0.lastPathComponent) }
        summary.themes = copyNew("Themes")
        if let modelFileName {
            let from = source.appendingPathComponent("Models/\(modelFileName)")
            let models = SuperNotesPaths.ensure(support.appendingPathComponent("Models", isDirectory: true))
            let to = models.appendingPathComponent(modelFileName + ".partial")
            if fm.fileExists(atPath: from.path), !isSymlink(from), !fm.fileExists(atPath: models.appendingPathComponent(modelFileName).path) {
                try? fm.removeItem(at: to)
                if (try? fm.copyItem(at: from, to: to)) != nil { summary.models = [modelFileName] }
            }
        }
        Log.store.info("imported from the direct edition: \(summary.text, privacy: .public)")
        return summary
    }

    /// The extensions the direct edition installed from GitHub, from its preferences file.
    public static func githubExtensions(inPreferences plist: URL) -> Set<String> {
        guard let values = NSDictionary(contentsOf: plist) as? [String: Any],
              let data = values["extensions.sources"] as? Data,
              let sources = try? JSONDecoder().decode([String: String].self, from: data) else { return [] }
        return Set(sources.keys)
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
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.udsy.supernotes").isEmpty {
            return Alerts.error("Quit the direct-download Super Notes first, so its notes are copied in one piece.")
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = Distribution.directSupportFolder
        panel.prompt = "Import"
        panel.message = "Choose the “Super Notes” folder of the direct-download edition. Its notes, extensions and themes are copied here; the original is left as it is."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        // The settings file says which extensions were your own and which came from GitHub (those stay behind).
        var prefsURL: URL?
        if Alerts.confirm("Import settings and your own extensions too?",
                          info: "Choose the direct edition's preferences file (com.udsy.supernotes.plist). It brings themes, keywords and shortcuts, and tells your own extensions apart from ones installed from GitHub, which this edition doesn't use.",
                          confirmTitle: "Choose File…", cancelTitle: "Just Notes") {
            let prefs = NSOpenPanel()
            prefs.allowedContentTypes = [.propertyList]
            prefs.directoryURL = Distribution.directPreferencesFile.deletingLastPathComponent()
            prefs.message = "Choose com.udsy.supernotes.plist"
            if prefs.runModal() == .OK { prefsURL = prefs.url }
        }
        do {
            let summary = try importData(from: folder, into: store, modelFileName: Services.ai?.modelFileName,
                                         githubExtensions: prefsURL.map(githubExtensions(inPreferences:)))
            if !summary.models.isEmpty { Services.ai?.adoptImportedModel() }
            var text = "Imported \(summary.text)"
            if let prefsURL { text += ", \(try importPreferences(from: prefsURL)) settings" }
            if !summary.skippedExtensions.isEmpty { text += " · \(summary.skippedExtensions.count) extension(s) left behind" }
            HUD.show(text, kind: .success)
        } catch {
            Alerts.error("Couldn't import from the direct-download edition.", error)
        }
    }
    #endif
}
