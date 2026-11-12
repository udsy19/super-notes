// swift-tools-version:5.10
import PackageDescription

// Super Notes — a scratchpad for macOS. Feature modules depend only on SuperNotesCore; the app target wires them
// together through the `Services` registry.
//
// Two editions from one codebase. `SUPERNOTES_DISTRIBUTION=appstore` (set by `DISTRIBUTION=appstore
// scripts/build-app.sh`) builds the Mac App Store edition: every target gets the `APP_STORE` condition and UpdateKit
// (the GitHub self-updater) isn't compiled or linked at all. Anything else builds the direct-download edition.
let appStore = Context.environment["SUPERNOTES_DISTRIBUTION"] == "appstore"
let allModules = [
    "StorageKit",     // SQLite note store, The Void, backups, encrypted iCloud Drive sync
    "NoteEngine",     // first-line keywords, math & units & currencies, sum/avg/count, lists, links, paste cleaning
    "ExtensionsKit",  // JavaScript extensions (JavaScriptCore), `::` commands, API bridge, bundled extensions
    "EditorKit",      // the plain-text editor: checklists, inline results, links, code, Vim mode, find & replace
    "ShellKit",       // main window & presence, swipe deck, slots, global hotkey, menus, settings, themes, locking,
                      // onboarding & tutorial notes
    "ToolsKit",       // timers & pomodoro, export, URL scheme, command palette, The Void, search
    "UpdateKit",      // background updates from GitHub Releases: check, verify, stage, swap on quit or when idle
    "AIKit",          // the AI engines behind `::ask` & co: on-device llama.cpp model (downloaded in the background),
                      // Apple's on-device model on macOS 26, or an installed command-line tool
]
let modules = appStore ? allModules.filter { $0 != "UpdateKit" } : allModules
let settings: [SwiftSetting] = appStore ? [.define("APP_STORE")] : []

let package = Package(
    name: "SuperNotes",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SuperNotes", targets: ["SuperNotes"])],
    targets: [
        .target(name: "SuperNotesCore", path: "Sources/SuperNotesCore", swiftSettings: settings),
        // llama.cpp's official release xcframework (MIT): a universal macOS dynamic framework with Metal embedded, so
        // no Xcode or `metal` compiler is needed. The checksum is `swift package compute-checksum` of the zip; the
        // same pin as the sister project. scripts/build-app.sh embeds it in Contents/Frameworks.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11721/llama-b11721-xcframework.zip",
            checksum: "9efc8f94a7fb54abb4931bac484a025417cee5bbf8e15ba49b4d9ddef997460f"),
        .executableTarget(name: "SuperNotes", dependencies: ["SuperNotesCore"] + modules.map { .target(name: $0) },
                          path: "Sources/SuperNotes", swiftSettings: settings),
        .executableTarget(name: "SuperNotesSelfTest", dependencies: ["SuperNotesCore"] + modules.map { .target(name: $0) },
                          path: "Sources/SuperNotesSelfTest", swiftSettings: settings),
        // Offscreen PNG renders of the UI for visual checks: `.build/debug/SuperNotesRender <out-dir> [scene…]`.
        .executableTarget(name: "SuperNotesRender", dependencies: ["SuperNotesCore"] + modules.map { .target(name: $0) },
                          path: "Tools/SuperNotesRender", swiftSettings: settings),
    ] + modules.map { name -> Target in
        switch name {
        case "ExtensionsKit": .target(name: name, dependencies: ["SuperNotesCore"], path: "Sources/\(name)", resources: [.copy("Bundled")], swiftSettings: settings)
        case "AIKit": .target(name: name, dependencies: ["SuperNotesCore", "llama"], path: "Sources/\(name)", swiftSettings: settings)
        default: .target(name: name, dependencies: ["SuperNotesCore"], path: "Sources/\(name)", swiftSettings: settings)
        }
    }
)
