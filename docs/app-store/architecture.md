# Architecture of the Store edition

## Build selection
`Package.swift` reads `SUPERNOTES_DISTRIBUTION`. When it is `appstore`, every target is compiled with
`.define("APP_STORE")` and the `UpdateKit` target is removed from the module list, so the GitHub self-updater is
neither compiled into nor linked with the app. `scripts/build-app.sh` sets the variable for `DISTRIBUTION=appstore`
and uses its own scratch path (`.build-appstore`) and output folder (`build/appstore`). Runtime code asks
`Distribution.isAppStore` (SuperNotesCore/System.swift) where a branch is cheaper than `#if`.

Deviation from the shared brief: the brief names `-Xswiftc -DAPP_STORE` as the switch. A flag alone cannot remove a
SwiftPM target from the link, so the manifest-level variable is the source of truth; it also defines `APP_STORE`.

## What differs in the Store edition
| Area | Direct edition | Store edition | Where |
|---|---|---|---|
| Updates | UpdateKit (GitHub Releases, swap on quit) | Not built. Settings → Updates says "Updates come from the Mac App Store." | Package.swift, main.swift, SettingsPanes.swift |
| Extensions | Bundled + user folder + install/update from GitHub | Bundled + user-authored only; GitHub install/update compiled out | ExtensionsKit/Community.swift, SettingsView.swift |
| AI engines | Downloaded llama.cpp model, Apple model, installed CLI tools (codex/claude/gemini) | Downloaded model + Apple model; CLI engine compiled out (a synced choice falls back) | AIKit/CommandLineEngine.swift, EngineSelection.swift, AIService.swift |
| Model download | Automatic, 3 min after launch, policy-gated | Off by default; "Download Now" shows size/licence/source and asks first | Settings.swift (`aiAutoDownload`), AIService.downloadNow |
| Export → Apple Notes | AppleScript (Apple Events) | Notes' share extension (`com.apple.Notes.SharingExtension`), no Apple Events | ToolsKit/Export/ExportManager.swift |
| iCloud Drive sync | Fixed path `~/Library/Mobile Documents/com~apple~CloudDocs/Super Notes` | User picks the folder once (security-scoped bookmark, `Choose iCloud Drive Folder…`) | StorageKit/ICloudDriveSync.swift |
| Existing data | — | Settings → Notes → "Import from Super Notes (direct download)…": copies notes/extensions/themes/model + settings | StorageKit/DirectEditionImport.swift |
| Info.plist | as is | bundle ID `.appstore`; `NSAppleEventsUsageDescription` removed | scripts/build-app.sh |

Everything else (editor, checklists, math/units/currencies, timers & pomodoro, search, history/undo, The Void,
backups, locking with Touch ID, global hotkey, URL scheme, themes, export to files/Obsidian/Bear/custom URL,
JSON import/export, login item) is the same code in both editions; the ones that touch the system were exercised in
the sandbox (see test-results.md).

## Data
Store edition data lives in `~/Library/Containers/com.udsy.supernotes.appstore/Data/Library/Application Support/Super Notes`.
The direct edition's folder is never moved or modified. No `container-migration.plist` is used (different bundle
ID; the brief forbids it). TCC grants (Automation, notifications, login item) do not transfer between editions.

Import flow: NSOpenPanel opens at the direct edition's folder (`Distribution.directSupportFolder`, real home via
`getpwuid`), the user confirms, the database is copied to the container's temp folder (with `-wal`/`-shm`), opened
there and merged with `importJSON` (newer edits win). Refused: a running direct edition (quit it first), a
symlinked `notes.sqlite`/`-wal`/`-shm` (SQLite would write through it), and a copy that recovers to zero notes
(torn mid-write). `Themes/` are copied when not already present; symlinks are skipped. Only the catalog model
(`Qwen3.5-2B-Q4_K_M.gguf`) is copied, as `.partial`, and AIKit installs it only if its SHA-256 matches. An optional
panel picks `~/Library/Preferences/com.udsy.supernotes.plist`: it supplies the shareable settings
(`PreferencesSync.keyNames`) and the direct edition's `extensions.sources`, so only the user's own extensions are
copied and GitHub-installed ones stay behind (without that file no extension is copied). Keychain items (sync key, extension
API keys) cannot be read across editions: the sync key moves with the existing "Copy Encryption Key / Paste Key"
buttons, API keys are re-entered.

## Signing
`scripts/package-appstore.sh`: build → `xattr -cr` (strip quarantine) → embed `embedded.provisionprofile` → sign
`llama.framework` → sign the app with the Store entitlements merged with the profile's application identifier and
team → refuse forbidden entitlements → `productbuild --component … /Applications --sign <installer>`. With
`ADHOC=1` it stops after an ad-hoc signature for local sandbox testing.

## Why the direct edition has `disable-library-validation`
The direct edition is signed with a self-signed "Super Notes Local Signing" identity (scripts/signing-setup.sh)
with hardened runtime. Such an identity has no Apple Team ID, and hardened-runtime library validation only loads
libraries signed by the same Team ID (or Apple), so the embedded `llama.framework` would be refused at launch. The
Store edition doesn't need it: Apple Distribution signs the framework and the app with the same Team ID. The ad-hoc
test build has no hardened runtime, so library validation isn't in play there either. If the direct edition moves
to a Developer ID certificate, the entitlement can be dropped there too (owner decision, known-blockers.md).
