# Test results (2026-11-12, macOS 26.5.1 arm64, Command Line Tools only, ad-hoc signing)

## Self-tests (headless, both editions)
```
swift build && .build/debug/SuperNotesSelfTest                       → All self-tests passed.
SUPERNOTES_DISTRIBUTION=appstore swift build --scratch-path .build-appstore
.build-appstore/debug/SuperNotesSelfTest                             → All self-tests passed.
```
New case `StorageKit.directEditionImport` (both editions): a fixture laid out like the direct edition's
`Application Support/Super Notes` (notes.sqlite + WAL, Extensions/, Themes/, Models/*.gguf and a `.partial`) is
imported into another store: notes merged, folders copied, `.partial` skipped, source listing byte-identical
afterwards, a second import is a no-op, a folder without notes is refused, only shareable settings are applied.
Store-only adjustments: UpdateKit, GitHub-extension and CLI-engine cases are compiled out with their code; the
engine-selection case asserts the Store fallback instead.
Known flake (pre-existing, timing-based, both editions, ~1 run in 3 while the CPU is busy):
`EditorKit.undoSurvivesAutosave` waits a fixed 0.5 s for a debounced save. Not touched by this branch.

## Sandboxed experiments (ad-hoc signed, App Sandbox enforced)
Build: `ADHOC=1 ./scripts/package-appstore.sh --debug`, then
`"build/appstore/Super Notes.app/Contents/MacOS/SuperNotes" --sandbox-probe --with-model` (debug-only harness,
Sources/SuperNotes/SandboxProbe.swift; not in release builds — `strings` count 0).
```
PROBE edition INFO appStore=true bundle=com.udsy.supernotes.appstore
PROBE sandboxed PASS APP_SANDBOX_CONTAINER_ID=com.udsy.supernotes.appstore
PROBE container PASS ~/Library/Containers/com.udsy.supernotes.appstore/Data/Library/Application Support/Super Notes
PROBE notes.sqlite PASS …/Super Notes/notes.sqlite
PROBE keychain.generic PASS SecItemAdd/CopyMatching on the app's own item
PROBE keychain.dataProtection INFO OSStatus -34018 (missing application-identifier: expected ad-hoc; falls back to the local item)
PROBE direct-folder.noPick PASS ~/Library/Application Support/Super Notes exists=true readable=false
PROBE outside-container.noPick PASS ~/Library/Preferences readable=false
PROBE icloud-drive.noPick PASS readable=false (sync uses a picked folder)
PROBE import.fixture PASS 1 note, 1 extension
PROBE network.client PASS HTTP 200, 2962 bytes
PROBE extension.bundled PASS ::upper(probe) → replaceLine("PROBE")
PROBE extension.userAuthored PASS ::probemine → insert("mine:42")
PROBE export.appleNotesShare PASS service=true            (canPerform; the sheet itself needs a human)
PROBE hotkey.register PASS token=Optional(1)              (Carbon RegisterEventHotKey, no TCC)
PROBE loginItem.status INFO SMAppService.mainApp.status=3 (not registered; registering needs the user)
PROBE notifications.settings PASS authorizationStatus=0
PROBE model.download PASS installed in 107 s → …/Super Notes/Models/Qwen3.5-2B-Q4_K_M.gguf
PROBE model.readiness PASS ready engine=onDevice
PROBE model.sha256 PASS aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223
PROBE model.inference PASS ::ask → insert("4") in 7.8 s (cold), 0.8 s (warm), GPU offload true
PROBE done failures=0
```
`direct-folder.noPick` was run with a temporary fixture file created at the real path and removed afterwards.
The model run used AIKit's downloader and folder with the probe overriding the Low-Power-Mode/unmetered policy
(this Mac was in Low Power Mode, which the shipping policy correctly refused on the first attempt:
`waiting(lowPower)`). Model inference ran `::ask` end to end: bundled JS → `AI.complete` → `AIService` →
`llama.framework` with Metal, in the sandbox, without `disable-library-validation`.

Sandbox denial log (`/usr/bin/log show --predicate 'sender == "Sandbox"' --start … | grep SuperNotes`):
```
Sandbox: SuperNotes(39904) deny(1) file-read-data /Users/udsy/Library/Preferences                         ← probe, expected
Sandbox: SuperNotes(39904) deny(1) file-read-data /Users/udsy/Library/Mobile Documents/com~apple~CloudDocs ← probe, expected
Sandbox: SuperNotes(39904) deny(1) file-issue-extension target:/ extension-class:com.apple.app-sandbox.read
```
The third line appeared once during the model run; nothing failed (download, hash, load and inference all PASS). Cause not identified;
listed in known-blockers as "observe in a full Store-signed run".

## Bug found and fixed
Exiting while the llama model is loaded aborted in ggml-metal's static destructor
(`ggml-metal-device.m:1041: GGML_ASSERT([rsets->data count] == 0)`, exit 134, crash report written). Any quit within
10 minutes of an AI command hit this in both editions. Fix: `AIService.unloadBeforeQuit()` on
`willTerminateNotification` (AIKitModule). Re-run: exit 0, no backtrace.

## Release build and GUI launch
`ADHOC=1 ./scripts/package-appstore.sh` (release): entitlements = app-sandbox, network.client,
files.user-selected.read-write, files.bookmarks.app-scope; Info.plist bundle ID `com.udsy.supernotes.appstore`,
no `NSAppleEventsUsageDescription`; `Contents/Resources/Licenses/llama.cpp-LICENSE.txt` present; `strings`:
`/opt/homebrew|/usr/local` 0, probe 0, `NSAppleScript` imports 0 (the only `github` strings are Privacy-pane labels
that the Store build filters out at runtime). `open`ed the app: ran 8 s sandboxed, zero SuperNotes sandbox denials,
exited cleanly on SIGTERM.
`./scripts/package-appstore.sh` without credentials: exits 2 naming the three missing variables.
Direct edition `./scripts/build-app.sh`: unchanged output (`build/Super Notes.app`, bundle `com.udsy.supernotes`,
apple-events + disable-library-validation, local identity).

## Needs a human run (exact steps)
1. `ADHOC=1 ./scripts/package-appstore.sh && open "build/appstore/Super Notes.app"`.
2. Settings → Notes → Import from Super Notes (direct download)… → pick `~/Library/Application Support/Super Notes`
   → expect the HUD "Imported N notes…"; then Choose File… → `~/Library/Preferences/com.udsy.supernotes.plist`.
3. Settings → General → Sync notes with iCloud on → Choose iCloud Drive Folder… → iCloud Drive → status "Synced";
   quit and relaunch → still "Synced" (bookmark). Check `…/CloudDocs/Super Notes/notes/` holds encrypted (JOT1) files.
4. Export → Apple Notes on a note → Notes' share sheet appears → Save → note in Notes.
5. Export → Markdown/PDF/All Notes to ~/Desktop via the save panel.
6. Settings → AI → Download Now → alert shows 1.28 GB → (model already present after step 2 if imported).
7. Settings → General → Launch at login on → System Settings › Login Items lists Super Notes.
8. Lock a note (⇧⌘L) → Touch ID prompt.
After each: `/usr/bin/log show --predicate 'sender == "Sandbox"' --last 10m | grep SuperNotes` should be empty.
