# Vault

[中文](README.md) | **English**

> A local-first macOS app for managing sensitive secrets

![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-purple)
![Encryption](https://img.shields.io/badge/Encryption-AES--256--GCM-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

[Features](#features) · [Quick Start](#quick-start) · [Data & Security](#data--security) · [Backup & Restore](#backup--restore) · [Project Structure](#project-structure)

---

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

## Quick Start

**Option 1: Download DMG (recommended)**

Go to [Releases](../../releases) and download the latest DMG. Drag it into Applications.

On first launch macOS may block the app — right-click → Open → Open again to proceed.

**Option 2: Build from source**

```bash
git clone https://github.com/lusgt/Vault.git
cd Vault
open Vault.xcodeproj
```

Select the `Vault` target in Xcode and run. Requires macOS 13+ and Xcode 15+.

---

## Data & Security

- Master password key derivation: PBKDF2-SHA256 (200,000 iterations)
- Content and metadata encrypted separately with AES-256-GCM
- SQLite WAL mode + secure_delete
- Clipboard auto-clears after a configurable delay; clears immediately on lock or exit
- Data stored locally at `~/Library/Application Support/Vault/`

See [SECURITY_EN.md](SECURITY_EN.md) · [PRIVACY_EN.md](PRIVACY_EN.md) for details.

---

## Backup & Restore

- Backup files are encrypted binary blobs stored locally
- Backup password is completely independent from the master password
- Backups are device-independent — restore on any Mac with Vault installed
- Export or import backups at any time from the Settings page

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
