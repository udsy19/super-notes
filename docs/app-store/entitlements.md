# Entitlements

## Store edition — `Resources/SuperNotes-AppStore.entitlements`
| Key | Why | Evidence |
|---|---|---|
| `com.apple.security.app-sandbox` | Required (2.4.5(i)) | probe `sandboxed PASS`, container path |
| `com.apple.security.network.client` | Model download (huggingface.co), currency rates (open.er-api.com, api.coingecko.com), extension API calls the user allows | probe `network.client PASS`, `model.download` |
| `com.apple.security.files.user-selected.read-write` | Export/print/backup panels, JSON import, direct-edition import, picked sync folder | NSOpenPanel/NSSavePanel flows (human run, see test-results) |
| `com.apple.security.files.bookmarks.app-scope` | Keeps the picked iCloud Drive sync folder across launches | code path; needs human pick |

Added at signing time from the provisioning profile: `com.apple.application-identifier`,
`com.apple.developer.team-identifier` (enables the data-protection keychain the sync key prefers).

Deliberately **absent**: `automation.apple-events` (Export → Apple Notes uses Notes' share extension instead),
`cs.disable-library-validation` (same-team signing), `cs.allow-unsigned-executable-memory` (JavaScriptCore's JIT
needs nothing in the sandbox; probe ran JS), `inherit` (no helper processes; the CLI-tool engine is compiled out),
`network.server`, any `temporary-exception`. `package-appstore.sh` fails the build if a forbidden key appears.

Not needed for: Touch ID (LocalAuthentication), the global hotkey (Carbon `RegisterEventHotKey`, probe PASS),
notifications (UNUserNotificationCenter), the login item (`SMAppService.mainApp`), the `supernotes://` URL scheme,
Notes' share extension.

Optional, owner decision: iCloud Keychain sync of the encryption key across Macs needs the data-protection keychain
(application identifier from the profile) — no extra entitlement. A CloudKit/ubiquity container is NOT used.

## Direct edition — `Resources/SuperNotes.entitlements` (unchanged)
`automation.apple-events` (Export → Apple Notes via AppleScript) and `cs.disable-library-validation` (self-signed
identity has no Team ID; see architecture.md).
