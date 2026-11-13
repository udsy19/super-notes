# Dependency and licence audit

| Component | Version | Licence | Kind | Bundled | Sandbox OK | Notes |
|---|---|---|---|---|---|---|
| llama.cpp (llama.framework, ggml + Metal) | b11721 release xcframework, SwiftPM checksum `9efc8f94…460f` | MIT | dynamic framework (binary target) | `Contents/Frameworks/llama.framework` | Yes — loaded and ran Metal inference in the ad-hoc sandboxed build | Notice now shipped at `Contents/Resources/Licenses/llama.cpp-LICENSE.txt` (was missing before this branch) |
| Qwen3.5 2B Q4_K_M GGUF | HF commit f6d5376 | Apache-2.0 | data (downloaded on consent) | No | Yes | Container `Models/` |
| Bundled JS extensions (10) | in repo | MIT (Super Notes) | scripts in resource bundle | Yes | Yes | reviewed with the app |
| Apple frameworks | macOS 14+ SDK | Apple | system | — | Yes | AppKit, SwiftUI, JavaScriptCore, CryptoKit, SQLite3, FoundationModels (macOS 26), LocalAuthentication, ServiceManagement, UserNotifications, Carbon (hotkey) |

No GPL/LGPL code. No Swift package dependencies besides the binary target. No Homebrew/`/usr/local` references in
the Store binary (the CLI-tool search paths are compiled out; checked with `strings`, see test-results.md).
Super Notes itself: MIT.
