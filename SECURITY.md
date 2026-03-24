# Security / 安全说明

**中文** | **English**

---

## 概览 / Overview
Vault 采用本地优先安全模型，所有敏感数据仅保存在本地并进行加密，不依赖云端。

Vault follows a local-first security model. Sensitive data is stored and encrypted on-device only and does not rely on any cloud service.

---

## 加密模型 / Cryptography
- 密钥派生：PBKDF2-SHA256（200,000 次）
- 加密算法：AES-256-GCM
- 备份文件：独立备份密码 + AES-256-GCM

- Key derivation: PBKDF2-SHA256 (200,000 iterations)
- Encryption: AES-256-GCM
- Backups: Separate backup password + AES-256-GCM

---

## 数据存储 / Data at Rest
- SQLite 本地数据库
- WAL 模式 + secure_delete
- 主要内容与元数据均加密

- Local SQLite database
- WAL mode + secure_delete
- Main content and metadata are encrypted

---

## 剪贴板 / Clipboard
- 复制内容会在设定时间后自动清空
- 锁定/退出时会立即清空

- Copied content is auto-cleared after a configurable delay
- Cleared immediately on lock/exit

---

## 备份 / Backup
- 备份文件为加密二进制格式（本地保存）
- 备份密码与主密码独立

- Backup files are encrypted binary blobs (stored locally)
- Backup password is independent from the master password

---

## 安全边界 / Threat Model
- 不提供云端同步
- 不对抗设备被物理入侵的情况
- 不对抗已被系统级恶意软件控制的设备

- No cloud sync
- Does not protect against physical device compromise
- Does not protect against system-level malware

---

## 报告安全问题 / Reporting
若发现安全问题，请通过私信或安全渠道联系维护者。

If you discover a security issue, please contact the maintainer via a private channel.
