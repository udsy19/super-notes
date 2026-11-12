#if DEBUG
import AppKit
import Security
import ServiceManagement
import UserNotifications
import SuperNotesCore
import StorageKit
import ExtensionsKit
import AIKit

/// Debug builds only: `SuperNotes --sandbox-probe [--with-model]` exercises the features that touch the system from
/// inside the running (sandboxed, when signed so) app and prints one `PROBE <name> PASS|FAIL|INFO <detail>` line each,
/// then exits. It is the evidence behind docs/app-store/test-results.md; release builds don't contain it.
@MainActor
enum SandboxProbe {
    static var failed = 0

    static func report(_ name: String, _ ok: Bool?, _ detail: String) {
        let verdict = ok == nil ? "INFO" : ok! ? "PASS" : "FAIL"
        if ok == false { failed += 1 }
        print("PROBE \(name) \(verdict) \(detail)")
        fflush(stdout)
    }

    static func pump(until done: () -> Bool, seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while !done() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    static func run(withModel: Bool) -> Never {
        let fm = FileManager.default
        let support = SuperNotesPaths.support
        report("edition", nil, "appStore=\(Distribution.isAppStore) bundle=\(Bundle.main.bundleIdentifier ?? "-")")
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        report("sandboxed", sandboxed, "APP_SANDBOX_CONTAINER_ID=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] ?? "nil")")
        report("container", support.path.contains("/Library/Containers/"), support.path)

        // Notes database in the container.
        do {
            let store = try SQLiteNoteStore()
            let note = store.create(content: "probe \(Date())")
            store.checkpoint()
            let reopened = try SQLiteNoteStore()
            report("notes.sqlite", reopened.note(note.id) != nil, SuperNotesPaths.database.path)
        } catch { report("notes.sqlite", false, "\(error)") }

        // Keychain: the app's own generic passwords (extension API keys), and the data-protection keychain the
        // sync key prefers (needs the application identifier a provisioning profile brings).
        Keychain.set("probe-secret", for: "probe")
        report("keychain.generic", Keychain.get("probe") == "probe-secret", "SecItemAdd/CopyMatching on the app's own item")
        Keychain.set(nil, for: "probe")
        let dpQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "probe.dp",
                                      kSecAttrAccount as String: "probe", kSecUseDataProtectionKeychain as String: true,
                                      kSecValueData as String: Data("x".utf8)]
        let dp = SecItemAdd(dpQuery as CFDictionary, nil)
        SecItemDelete(dpQuery.filter { $0.key != kSecValueData as String } as CFDictionary)
        report("keychain.dataProtection", nil, "OSStatus \(dp) (-34018 = missing application-identifier: expected ad-hoc; the sync key then falls back to the local item)")

        // Outside the container: denied without the user's pick.
        let direct = Distribution.directSupportFolder
        let directReadable = (try? fm.contentsOfDirectory(atPath: direct.path)) != nil
        report("direct-folder.noPick", !directReadable || !sandboxed, "\(direct.path) exists=\(fm.fileExists(atPath: direct.path)) readable=\(directReadable) (must be false: import goes through NSOpenPanel)")
        let prefs = Distribution.userHome.appendingPathComponent("Library/Preferences")
        let prefsReadable = (try? fm.contentsOfDirectory(atPath: prefs.path)) != nil
        report("outside-container.noPick", !prefsReadable || !sandboxed, "\(prefs.path) readable=\(prefsReadable) (must be false)")
        let cloud = Distribution.userHome.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let cloudReadable = (try? fm.contentsOfDirectory(atPath: cloud.path)) != nil
        report("icloud-drive.noPick", !cloudReadable || !sandboxed, "readable=\(cloudReadable) (must be false: sync uses a picked folder)")

        // Import logic on a fixture inside the container (the panel grant itself needs a human click).
        do {
            let fixture = fm.temporaryDirectory.appendingPathComponent("direct-fixture/Super Notes", isDirectory: true)
            try? fm.removeItem(at: fixture.deletingLastPathComponent())
            try fm.createDirectory(at: fixture.appendingPathComponent("Extensions/fixture-ext"), withIntermediateDirectories: true)
            let source = try SQLiteNoteStore(url: fixture.appendingPathComponent("notes.sqlite"), backupsFolder: fixture.appendingPathComponent("Backups"))
            _ = source.create(content: "imported from direct")
            try "{}".write(to: fixture.appendingPathComponent("Extensions/fixture-ext/extension.json"), atomically: true, encoding: .utf8)
            let target = try SQLiteNoteStore()
            let summary = try DirectEditionImport.importData(from: fixture, into: target)
            report("import.fixture", summary.notes == 1 && target.deck.contains { $0.content == "imported from direct" }, summary.text)
            try? fm.removeItem(at: support.appendingPathComponent("Extensions/fixture-ext"))
        } catch { report("import.fixture", false, "\(error)") }

        // Network client: currency rates endpoint.
        var net: String?
        URLSession.shared.dataTask(with: URL(string: "https://open.er-api.com/v6/latest/USD")!) { data, response, error in
            net = error.map { "error \($0.localizedDescription)" } ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0), \(data?.count ?? 0) bytes"
        }.resume()
        pump(until: { net != nil }, seconds: 20)
        report("network.client", net?.hasPrefix("HTTP 200") == true, net ?? "timeout")

        // Extensions: a bundled one and one the user wrote in the container's Extensions folder.
        Defaults[.extensionsEnabled] = true
        let mine = SuperNotesPaths.extensions.appendingPathComponent("probe-mine", isDirectory: true)
        try? fm.createDirectory(at: mine, withIntermediateDirectories: true)
        try? #"{"name":"probe-mine","version":"1.0.0"}"#.write(to: mine.appendingPathComponent("extension.json"), atomically: true, encoding: .utf8)
        try? """
        (function () { var e = new Extension({ name: "probe-mine" });
          new Command({ name: "probemine", type: "insert", parameters: [], extension: e, execute: function () { return "mine:" + (2 * 21); } }); })();
        """.write(to: mine.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)
        let extensions = ExtensionsManager()
        Services.extensions = extensions
        func runCommand(_ invocation: String, _ seconds: TimeInterval = 10) -> ExtensionEdit? {
            var result: ExtensionEdit?
            _ = extensions.run(invocation: invocation, line: invocation, note: invocation, progress: { _ in }) { result = $0 }
            pump(until: { result != nil }, seconds: seconds)
            return result
        }
        let upper = runCommand("::upper(probe)")
        report("extension.bundled", upper == .insert("PROBE") || upper == .replaceLine("PROBE"), "::upper(probe) → \(String(describing: upper))")
        let own = runCommand("::probemine")
        report("extension.userAuthored", own == .insert("mine:42"), "::probemine → \(String(describing: own))")
        try? fm.removeItem(at: mine)

        // Apple Notes through its share extension (no Apple Events).
        let share = NSSharingService(named: NSSharingService.Name("com.apple.Notes.SharingExtension"))
        report("export.appleNotesShare", share?.canPerform(withItems: ["probe"]) == true, "service=\(share != nil)")

        // Global hotkey (Carbon RegisterEventHotKey).
        let token = HotkeyCenter.shared.register(Shortcut(keyCode: 0x2F, modifiers: [.control, .option, .command, .shift])) {}
        report("hotkey.register", token != nil, "token=\(String(describing: token))")
        if let token { HotkeyCenter.shared.unregister(token) }

        // Login item and notifications: status only (registering asks the user).
        report("loginItem.status", nil, "SMAppService.mainApp.status=\(SMAppService.mainApp.status.rawValue)")
        var notif: String?
        UNUserNotificationCenter.current().getNotificationSettings { notif = "authorizationStatus=\($0.authorizationStatus.rawValue)" }
        pump(until: { notif != nil }, seconds: 5)
        report("notifications.settings", notif != nil, notif ?? "no answer")

        if withModel { probeModel(extensions: extensions, runCommand: runCommand) }
        print("PROBE done failures=\(failed)")
        exit(failed == 0 ? 0 : 1)
    }

    /// Downloads the real model through AIKit (consent is the probe operator's), verifies it, then answers `::ask`
    /// end to end: JavaScript → AI.complete → llama.framework with Metal, all inside the sandbox.
    static func probeModel(extensions: ExtensionsManager, runCommand: (String, TimeInterval) -> ExtensionEdit?) {
        Defaults[.aiEngine] = .onDevice
        // AIKit's own downloader and folder, with the probe overriding the "only on AC power / unmetered" policy.
        let downloader = ModelDownloader(spec: ModelCatalog.default, folder: SuperNotesPaths.models,
                                         conditions: { DownloadConditions(networkOK: true, lowPowerMode: false, freeDiskBytes: .max) })
        let started = Date()
        if !downloader.isInstalled { downloader.start() }
        var lastPrint = Date.distantPast
        pump(until: {
            if Date().timeIntervalSince(lastPrint) > 30 { print("PROBE model.progress INFO \(downloader.state)"); fflush(stdout); lastPrint = Date() }
            if case .failed = downloader.state { return true }
            if case .waiting = downloader.state { return true }
            return downloader.isInstalled
        }, seconds: 3600)
        report("model.download", downloader.isInstalled,
               "\(downloader.state) in \(Int(Date().timeIntervalSince(started))) s → \(downloader.fileURL.path)")
        guard downloader.isInstalled else { return }
        let ai = AIService.shared   // created after the download, so it finds the model installed
        Services.ai = ai
        report("model.readiness", ai.readiness == .ready, "\(ai.readiness) engine=\(ai.engine)")
        let sha = ModelDownloader.sha256(of: downloader.fileURL)
        report("model.sha256", sha == downloader.spec.sha256, sha ?? "unreadable")
        let t = Date()
        let answer = runCommand("::ask(What is 2+2? Reply with just the number.)", 300)
        report("model.inference", { if case .insert(let s)? = answer { return s.contains("4") }; return false }(),
               "::ask → \(String(describing: answer)) in \(String(format: "%.1f", Date().timeIntervalSince(t))) s, GPU offload \(LlamaEngine.supportsGPUOffload)")
        ai.unloadBeforeQuit()   // what quitting does (AIKitModule); exiting with the model loaded aborts in ggml-metal
    }
}
#endif
