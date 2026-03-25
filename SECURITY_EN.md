# Security

[中文](SECURITY.md) | **English**

---

## Overview

Vault follows a local-first security model. All sensitive data is stored and encrypted on-device only, with no cloud dependency.

---

## Cryptography

- Key derivation: PBKDF2-SHA256 (200,000 iterations)
- Encryption: AES-256-GCM
- Backups: Separate backup password + AES-256-GCM

---

## Data at Rest

- Local SQLite database at `~/Library/Application Support/Vault/`
- WAL mode + secure_delete
- Content and metadata are always encrypted; plaintext is never written to disk

---

## Clipboard

- Copied content is auto-cleared after a configurable delay
- Cleared immediately on lock or exit

---

## Backup

- Backup files are encrypted binary blobs stored locally
- Backup password is completely independent from the master password

---

## Threat Model

This app does not protect against:

- Physical device compromise
- System-level malware with full control of the device
- Users voluntarily disclosing their master or backup password

---

## Reporting a Vulnerability

If you discover a security issue, please contact the maintainer via GitHub Issues or a private channel. Do not disclose publicly before a fix is available.
