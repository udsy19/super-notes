import AppKit
import SuperNotesCore
import StorageKit
import NoteEngine
import ExtensionsKit
import EditorKit
import ShellKit
import ToolsKit
#if !APP_STORE
import UpdateKit   // the Mac App Store edition gets updates from the App Store; UpdateKit isn't even linked
#endif
import AIKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Order matters: storage and the engine first, then extensions and the editor, the shell last. UpdateKit
        // starts before the shell shows its window, so an "Updated to …" pill can greet that window.
        StorageKitModule.install()
        NoteEngineModule.install()
        ExtensionsKitModule.install()
        AIKitModule.install()
        EditorKitModule.install()
        ToolsKitModule.install()
        #if !APP_STORE
        UpdateKitModule.install()
        #endif
        ShellKitModule.install()
    }
}

let app = NSApplication.shared
#if DEBUG
if CommandLine.arguments.contains("--sandbox-probe") {
    MainActor.assumeIsolated { SandboxProbe.run(withModel: CommandLine.arguments.contains("--with-model")) }
}
#endif
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
