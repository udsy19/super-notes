# Notes for App Review (draft — paste into App Store Connect → App Review Information → Notes)

Super Notes is a plain-text scratchpad. The first word of a note picks a mode (`list`, `math`, `timer`, `code`, …).
No account, no sign-in, no servers of ours. Everything works offline.

**To try it:** press ⌥A (or click the Dock or menu bar icon) to open the note window. Type `math` on the first line, then
`12 km in miles` on the next. Type `timer 1m` to start a timer. Type `list` and `- milk` for a checklist.

## `::` commands and extensions (Guidelines 2.5.2, 4.7)
`::` commands (e.g. `::upper`, `::today`, `::json`) are small JavaScript files run by Apple's JavaScriptCore.
- **Built in:** ten extensions ship inside the app bundle (`Contents/Resources/SuperNotes_ExtensionsKit.bundle/Bundled`)
  and are part of what you review.
- **Written by the user:** like a scripting feature, a user can write their own command in a folder on their Mac
  (Settings → Extensions → Open Folder: `extension.json` + `index.js`). The app never downloads, installs or updates
  extensions in this edition: there is no gallery, store, catalog, URL install or update check. (The direct-download
  edition's "Install from GitHub" is not compiled into this build.)
- **Native surface exposed to scripts (4.7.2)** — the complete list: `console.log` (to the app's own log),
  `now()` (the time), `getPreference` / `getExtensionPreference` (the extension's own settings),
  `__evaluateMathExpression` (the app's math engine), `AI.complete` (the app's on-device AI, only for extensions that
  declare `"usesAI": true`), `callAPI` (an HTTPS request to an address the extension declares, refused unless the
  user turns on "Let extensions call their own APIs" in Settings → Privacy; off by default). No file system, process,
  Apple Events, pasteboard, camera, location or other platform API is bridged.

## On-device AI (Guidelines 4.2.3, 2.4.5(iv))
`::ask(question)`, `::summarize`, `::rewrite`, `::translate` run on this Mac. On macOS 26 with Apple Intelligence
on they use Apple's Foundation Models — nothing to download. Otherwise they need a 1.28 GB open-weights model
(Qwen3.5 2B, Apache-2.0) that is **only downloaded after the user agrees**:
1. Settings (⌘,) → AI → "On-device model" shows its name, size (1.28 GB), licence and source (huggingface.co).
2. Click **Download Now** → an alert repeats the size and source → **Download 1.28 GB**.
3. When the status says Installed (a few minutes on fast Wi-Fi; Download Now starts right away, even in Low Power
   Mode or on a metered connection — only the optional automatic download waits for those),
   type `::ask(What is the capital of France?)` on a new line in a note and press Return.
The file is model weights (data), checked against a SHA-256 pinned in the app, stored in the app's container and
read by the llama.cpp library bundled and signed in the app. No code is downloaded.

## Other things you may notice
- **iCloud sync** writes AES-GCM-encrypted files to a folder the user picks in iCloud Drive (Settings → General →
  Choose iCloud Drive Folder…). The key is created on the Mac and stored in the Keychain.
- **Export → Apple Notes** uses Notes' own share sheet (no Apple Events).
- **Import from Super Notes (direct download)…** (Settings → Notes) copies data from the free direct-download
  edition after the user picks its folder. It does nothing if that edition was never used. Extensions the direct
  edition installed from GitHub are not copied (only ones the user wrote); a copied AI model is installed only if
  its SHA-256 matches the pinned value.
- **Updates** come only from the Mac App Store; the app contains no updater.
- **Global hotkey** ⌥A uses `RegisterEventHotKey`; no Accessibility or Input Monitoring permission is requested.
- Optional **Launch at login** (Settings → General) uses `SMAppService` and is off by default.
