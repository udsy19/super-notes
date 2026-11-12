# Known blockers and owner decisions

## Blocked on credentials / tools (cannot be done on this Mac)
1. Apple Distribution + 3rd Party Mac Developer Installer certificates and a Mac App Store provisioning profile for
   `com.udsy.supernotes.appstore` (register the bundle ID in App Store Connect first). Then run
   `scripts/package-appstore.sh` with the three env vars (README).
2. Upload/validation: Xcode is not installed (no `altool`); use Transporter or install Xcode. Validation results
   (e.g. Info.plist / icon / entitlement checks done by the upload) are unknown until then.
3. Re-test with real signing: data-protection keychain (sync key via iCloud Keychain), library validation of
   llama.framework under the Distribution identity, and the one-off `file-issue-extension target:/` denial seen during the model run.
4. Direct edition Developer ID + notarization (credential-gated; not changed here). With a Developer ID identity the
   direct edition could also drop `disable-library-validation`.

## Material product changes needing owner approval (Store edition only; direct edition unchanged)
| Change | Why | In-app explanation |
|---|---|---|
| No "Install from GitHub" / extension update check | 2.5.2 / 2.4.5(iv): downloaded code; a 4.7 plug-in catalog would need moderation, an index with universal links, age gating | Settings → Extensions text: bundled + your own extensions; nothing is downloaded |
| No command-line AI engine (codex/claude/gemini) | Sandbox: tools outside the bundle can't be exec'd with their own credentials; Homebrew paths | Option absent in Settings → AI; a synced choice falls back to on-device |
| No self-updater | 2.4.5(vii) | Settings → Updates: "Updates come from the Mac App Store." |
| Model download asks first, off by default | 4.2.3 | Alert with size/licence/source |
| iCloud sync needs a one-time folder pick | Sandbox can't reach iCloud Drive by path | Status "Choose the iCloud Drive folder to sync with" + button |
| Export → Apple Notes via share sheet | No Apple Events in the Store build | Notes' own sheet |
| Separate data from the direct edition | Different bundle ID/container | Import button (copy, non-destructive) |

## Review risks / decisions
- **User-authored extensions.** We ship them (the user writes code locally, like a scripting feature; nothing
  downloaded, minimal documented bridge). A reviewer could still read 2.5.2 strictly. Fallback if rejected: in
  `ExtensionsManager.reload()` skip `userDirectory` under `APP_STORE` and hide Open Folder — bundled extensions keep
  working. Owner decides whether to pre-empt.
- `callAPI` lets a user's own extension make HTTPS calls to hosts it declares, off by default. Keep or remove in Store.
- "Sync extensions with iCloud" copies the user's own extensions between their Macs (not a download from us); keep.
- Export compliance answer (privacy-and-permissions.md): `ITSAppUsesNonExemptEncryption` intentionally not set.
- Model bundling vs download (model-and-asset-strategy.md): download chosen; bundling is the fallback if 2.4.5(iv) is read strictly.
- Store bundle ID `com.udsy.supernotes.appstore` is a placeholder (one variable in scripts/build-app.sh).
- Pricing / whether the Store edition is paid while the direct one is free.
