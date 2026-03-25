# Vault

[中文](README.md) | **English**

Vault is a local-first macOS app for managing sensitive secrets — API tokens, keys, SSH private keys, wallet mnemonics, recovery codes, and more. Everything is encrypted at rest on your device with no cloud dependency.

-「DONT TRUST, VERIFY」
---

## Features

- Local encrypted storage (AES-256-GCM)
- Master password protection with multi-level auto-lock (idle / sleep / window close)
- Text and binary attachments (images, screenshots, files, OTP backups)
- High-risk confirmation prompts for reveal, copy, and export actions
- Quick search, tags, favorites, and archiving
- Encrypted backup and restore with a separate backup password
- Chinese / English bilingual UI
- Light / Dark / System theme

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (to build)

---

## Build & Run

Open `Vault.xcodeproj` in Xcode, select the `Vault` target, and run.

Command-line build (unsigned):

```bash
xcodebuild \
  -project Vault.xcodeproj \
  -target Vault \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

---

## Data & Security

- Master password key derivation: PBKDF2-SHA256 (200,000 iterations)
- Content and metadata encrypted separately with AES-256-GCM
- SQLite WAL mode + secure_delete
- Clipboard auto-clears after a configurable delay; clears immediately on lock or exit

See [SECURITY.md](SECURITY.md) for details.

---

## Backup & Restore

- Backup files are encrypted binary blobs stored locally
- Backup password is completely independent from the master password
- Export or restore a backup at any time from the Settings page

---

## Project Structure

```
Vault/
  Models/          # Data models (Entry, RiskLevel, etc.)
  Services/        # Core services (crypto, database, clipboard, screen capture, etc.)
  Views/           # SwiftUI views
  en.lproj/        # English localization strings
  zh-Hans.lproj/   # Chinese localization strings
```

---

## License

This project is open source under the [MIT License](LICENSE). Copyright © 2026 DanL.
