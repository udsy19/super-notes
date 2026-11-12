# Compliance matrix (App Review Guidelines text checked 2026-11-12 at developer.apple.com/app-store/review/guidelines)

| Guideline | Requirement | Super Notes Store edition | Status |
|---|---|---|---|
| 2.4.5(i) | Sandboxed, container only | App Sandbox on; data in container; outside access only via user-picked panels/bookmarks; probe shows denials outside | Met (ad-hoc verified) |
| 2.4.5(ii) | Xcode-technology packaging, self-contained | SwiftPM → .app → codesign → `productbuild`; Apple's own tools, no third-party installer; llama.framework inside the bundle | Met in script; upload validation blocked (no Xcode/creds) |
| 2.4.5(iii) | No auto-launch without consent | Login item off by default, user toggle (`SMAppService.mainApp`) | Met |
| 2.4.5(iv) | No downloading code/resources that add functionality | Extensions never downloaded; model weights are data for features visible in review, opt-in with disclosure | Met; review-notes documents the model path |
| 2.4.5(vii) | Updates only via Mac App Store | UpdateKit not compiled/linked | Met |
| 2.5.1 | Public APIs | JavaScriptCore, FoundationModels, Carbon hotkey, LocalAuthentication, SMAppService, NSSharingService | Met |
| 2.5.2 | No downloading/executing code that changes features | GitHub install/update compiled out; only bundled JS + user-authored JS in the container | Met; user-authored scripts are a review judgement (known-blockers) |
| 4.2.3(ii) | Disclose size and prompt before required downloads | Model download off by default; size/licence/source alert before it starts | Met |
| 4.7 / 4.7.2 | Plug-ins: no native API exposure without permission | No plug-in catalog is offered; bridge limited to the documented minimal surface (review-notes) | Met by design (no 4.7 "offered software") |
| 5.1.1 | Privacy | No data collection; network calls listed with off switches; PRIVACY.md | Met |
| 5.1.2 | Data use | Note text leaves the Mac only via user-chosen exports, the user's own iCloud Drive (encrypted), or extension APIs the user enables | Met |
| Export compliance | Encryption declaration | Sync uses CryptoKit AES-GCM (Apple OS crypto) + HTTPS; `ITSAppUsesNonExemptEncryption` deliberately NOT set — owner answers in App Store Connect (privacy-and-permissions.md) | Owner decision |
| Apple Events | `automation.apple-events` needs scripting-targets | Removed; Notes share extension instead | Met |
| Hardened runtime / library validation | No `disable-library-validation` | Same-team signing of llama.framework | Met in script; verify with real certs |
| Quarantine | No quarantined files in upload | `xattr -cr` before signing | Met |
| Licences | No GPL; notices | llama.cpp MIT (notice bundled in `Contents/Resources/Licenses`), model Apache-2.0 | Met |
