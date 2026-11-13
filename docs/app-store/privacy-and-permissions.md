# Privacy and permissions

**Data collected by the developer: none.** No analytics, no accounts, no servers of ours. App Store privacy
label: "Data Not Collected". No PrivacyInfo.xcprivacy is needed on macOS for required-reason APIs; none added.

## Network calls (all listed in Settings → Privacy with an off switch)
| Call | Host | Default (Store) | Data sent |
|---|---|---|---|
| Currency rates | open.er-api.com, api.coingecko.com | on | none (GET) |
| AI model download | huggingface.co | **off** until the user agrees | none (GET) |
| iCloud Drive sync | the user's own iCloud Drive folder (file I/O, not our server) | off | AES-GCM-encrypted notes/settings |
| Extension APIs | only hosts each extension declares | off | whatever the user's extension sends |
Removed in the Store edition: GitHub Releases update checks, GitHub extension install/update.

## Permissions / TCC
| Prompt | When | Store edition |
|---|---|---|
| Touch ID / password (LocalAuthentication, `NSFaceIDUsageDescription`) | unlocking a locked note | same as direct |
| Notifications | timer/pomodoro end | same; status readable in sandbox (probe) |
| Login item | user turns on Launch at login | `SMAppService.mainApp` |
| Automation (Apple Events) | — | **not used** (`NSAppleEventsUsageDescription` removed from the Store Info.plist) |
| Accessibility / Input Monitoring / Screen Recording / Microphone | — | not used |
TCC grants made to the direct edition do not carry over (different bundle ID and signature).

## Keychain
- Extension API keys: generic passwords, service = bundle ID. Works in the sandbox (probe `keychain.generic PASS`).
- Sync key: synchronizable data-protection item when the app has an application identifier (provisioning
  profile), else a local item. Ad-hoc build: data-protection add returns -34018 (no application identifier) and
  the code falls back to the local item — expected; re-test with the real profile. No keychain access group is
  shared with the direct edition, so the key is moved with Copy/Paste Encryption Key.

## Encryption / export compliance (owner decision)
The app implements encryption of user data for sync: AES-256-GCM via Apple CryptoKit, key generated on device.
Plus HTTPS via URLSession. All of it is Apple-OS-provided standard cryptography used to protect the user's own
data, which normally qualifies for the exemption in App Store Connect's export compliance questions — but because
the app does implement encryption, we did **not** add `ITSAppUsesNonExemptEncryption = NO` to Info.plist. The
owner should answer the export compliance questions in App Store Connect (likely "uses encryption: yes; exempt:
yes, standard algorithms from the OS") and only then decide whether to set the key.
