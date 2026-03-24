# Vault

**中文** | **English**

Vault 是一个本地优先的敏感信息管理应用，面向 API Token、密钥、证书、助记词、恢复码等高敏感数据场景。所有内容在本地加密存储，不依赖云端。

Vault is a local-first secure vault for sensitive secrets such as API tokens, keys, certificates, mnemonics, and recovery codes. All content is encrypted at rest and stays on your device.

---

## 功能概览 / Features
- 本地加密存储（AES-256-GCM）
- 主密码保护与自动锁定
- 支持文本与二进制附件（图片/截图/文件）
- 快速搜索、标签、收藏、归档
- 备份与恢复（独立备份密码）
- 中英文双语界面

---

## 运行环境 / Requirements
- macOS 13+ (建议)
- Xcode 15+ (开发/构建)

---

## 构建与运行 / Build & Run
1. 使用 Xcode 打开 `Vault.xcodeproj`
2. 选择 `Vault` target
3. 直接运行

命令行构建（不签名）：

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

## 数据与安全 / Data & Security
- 主密码经 PBKDF2-SHA256-200k 派生密钥
- 内容与元数据分离加密
- SQLite WAL 模式 + secure_delete
- 剪贴板自动清空

更多细节见：`SECURITY.md`

---

## 备份与恢复 / Backup & Restore
- 备份文件为加密二进制格式（自定义备份密码）
- 备份密码与主密码独立

---

## 多语言 / Localization
- UI 语言支持中文与英文
- 语言切换后界面即时刷新
- 使用标准 `Localizable.strings`

---

## 项目结构 / Project Structure
```
Vault/
  Models/
  Services/
  Views/
  Assets.xcassets/
  en.lproj/
  zh-Hans.lproj/
```

---

## 许可证 / License
当前仓库为私有使用，仅供个人或团队内部使用。若需开源或对外发布，请先补充授权条款。

This repository is private and intended for internal use. Add a license before any public release.
