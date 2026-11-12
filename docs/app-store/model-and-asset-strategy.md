# Model and asset strategy

## The model
| | |
|---|---|
| Model | Qwen3.5 2B instruct, Q4_K_M GGUF (`Qwen3.5-2B-Q4_K_M.gguf`) — the only model in `AIKit/ModelCatalog.swift` |
| Source | `https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/…` (pinned commit) |
| Size | 1,280,835,840 bytes (1.28 GB), ~1.5 GB resident while loaded, unloaded after 10 idle minutes |
| SHA-256 | `aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223` (pinned in source; the file is moved into place only when it matches) |
| Licence | Apache-2.0 (Hugging Face card data for `unsloth/Qwen3.5-2B-GGUF`, base `Qwen/Qwen3.5-2B`) |
| Location | `~/Library/Containers/com.udsy.supernotes.appstore/Data/Library/Application Support/Super Notes/Models/` |

It is passive data (weights) read by the bundled, signed `llama.framework`; no code is downloaded (2.5.2).

## Why download instead of bundle
1.28 GB would multiply the app download for every user, while Macs with Apple Intelligence (macOS 26) answer with
Apple's on-device model and never need it. The smallest supported model is this one; there is no smaller catalog
entry. Bundling remains possible (copy into `Contents/Resources`, point `ModelDownloader` at it) if Review insists.

## Consent and disclosure (4.2.3, 2.4.5(iv))
- Store default: `aiAutoDownload = false`. Nothing downloads at launch.
- Settings → AI shows "Qwen3.5 2B (Q4_K_M) · 1.28 GB · Apache-2.0 · downloaded once from huggingface.co".
- "Download Now" opens an alert with name, size, licence, source and SHA-256 check; only "Download 1.28 GB" starts it.
- The "Download models automatically (1.28 GB)" switch (Settings → AI, Settings → Privacy) is the opt-in for background fetching.
- Downloads keep AIKit's policy: unmetered network, not in Low Power Mode, ≥ 10 GB free, low priority, resumable, SHA-256 checked.
- The features the model enables (`::ask`, `::summarize`, `::rewrite`, `::translate`) are visible in the binary
  and reviewable: see review-notes.md for the exact steps.

## Other downloaded data
Currency rates (JSON, open.er-api.com / api.coingecko.com, daily, switchable). Nothing else. Extensions are never downloaded in the Store edition.
