# Super Notes — Mac App Store edition

**Status: CODE COMPLETE / CREDENTIALS REQUIRED.** The sandboxed Store edition builds, passes the self-tests and
was exercised in an ad-hoc-signed sandboxed build (including a real on-device model download and inference).
Store signing, provisioning, `.pkg` validation and upload are blocked: this Mac has no Apple Distribution /
Installer identities, no provisioning profile and no Xcode. Nothing in these docs claims otherwise.

## Two editions, one codebase
| | Direct download | Mac App Store |
|---|---|---|
| Build | `./scripts/build-app.sh` (unchanged) | `DISTRIBUTION=appstore ./scripts/build-app.sh` |
| Swift condition | — | `APP_STORE` (set by `SUPERNOTES_DISTRIBUTION=appstore` in Package.swift) |
| Bundle ID | `com.udsy.supernotes` | `com.udsy.supernotes.appstore` (`APPSTORE_BUNDLE_ID` in scripts/build-app.sh) |
| Output | `build/Super Notes.app` | `build/appstore/Super Notes.app` |
| Entitlements | `Resources/SuperNotes.entitlements` | `Resources/SuperNotes-AppStore.entitlements` |

## Commands
```bash
# Store edition: compile + self-tests (separate build cache so the editions never mix)
SUPERNOTES_DISTRIBUTION=appstore swift build --scratch-path .build-appstore
.build-appstore/debug/SuperNotesSelfTest

# Local sandboxed test build (ad-hoc signed, sandbox enforced). --debug adds the --sandbox-probe harness.
ADHOC=1 ./scripts/package-appstore.sh --debug
"build/appstore/Super Notes.app/Contents/MacOS/SuperNotes" --sandbox-probe [--with-model]
/usr/bin/log show --predicate 'sender == "Sandbox"' --last 10m | grep SuperNotes

# Real submission package (needs credentials; fails loudly naming what is missing)
APPSTORE_APP_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)" \
APPSTORE_PROVISIONING_PROFILE=/path/SuperNotes_AppStore.provisionprofile \
UNIVERSAL=1 ./scripts/package-appstore.sh        # → dist/SuperNotes-<version>-AppStore.pkg
```
`swift build -c release -Xswiftc -DAPP_STORE` also compiles the Store code paths, but only the environment variable
removes UpdateKit from the link; use the scripts.

## Documents
[compliance-matrix](compliance-matrix.md) · [architecture](architecture.md) · [entitlements](entitlements.md) ·
[model-and-asset-strategy](model-and-asset-strategy.md) · [privacy-and-permissions](privacy-and-permissions.md) ·
[dependency-and-license-audit](dependency-and-license-audit.md) · [test-results](test-results.md) ·
[app-store-connect](app-store-connect.md) · [review-notes](review-notes.md) · [known-blockers](known-blockers.md) ·
[inventory.json](inventory.json)
