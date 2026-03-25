# Vault

**中文** | [English](README_EN.md)

> 本地优先的 macOS 敏感信息管理应用

![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-purple)
![Encryption](https://img.shields.io/badge/Encryption-AES--256--GCM-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

[功能概览](#功能概览) · [快速开始](#快速开始) · [数据与安全](#数据与安全) · [备份与恢复](#备份与恢复) · [项目结构](#项目结构)

---

Vault 是一款本地优先的 macOS 敏感信息管理应用，专为 API Token、密钥、SSH 私钥、钱包助记词、恢复码等高敏感数据场景设计。所有内容在本地加密存储，不依赖任何云服务。
          
-「DONT TRUST, VERIFY」
---

## 功能概览

- 本地加密存储（AES-256-GCM）
- 主密码保护与多级自动锁定（空闲 / 休眠 / 关闭窗口）
- 支持文本与二进制附件（图片、截图、文件、OTP 备份）
- 高风险条目二次确认（显示、复制、导出均需确认）
- 快速搜索、标签、收藏、归档
- 加密备份与恢复（独立备份密码）
- 中英文双语界面
- 浅色 / 深色 / 跟随系统主题

---

## 快速开始

**方式一：下载 DMG（推荐）**

前往 [Releases](../../releases) 下载最新版 DMG，拖入 Applications 即可。

首次打开时系统会拦截，右键点击 App → 打开 → 再次点击打开，之后正常使用。

**方式二：自行构建**

```bash
git clone https://github.com/lusgt/Vault.git
cd Vault
open Vault.xcodeproj
```

用 Xcode 选择 `Vault` target，直接运行即可。需要 macOS 13+ 和 Xcode 15+。

---

## 数据与安全

- 主密码经 PBKDF2-SHA256（200,000 次迭代）派生密钥
- 内容与元数据分离加密，均使用 AES-256-GCM
- SQLite WAL 模式 + secure_delete
- 剪贴板内容在可配置时间后自动清空，锁定或退出时立即清空
- 数据存储在本地：`~/Library/Application Support/Vault/`

详见 [SECURITY.md](SECURITY.md)

---

## 备份与恢复

- 备份文件为加密二进制格式，保存在本地
- 备份密码与主密码完全独立
- 备份文件跨设备可用，换电脑后导入即可完整恢复
- 在设置页面可随时导出或导入备份

---

## 项目结构

```
Vault/
  Models/          # 数据模型（Entry、RiskLevel 等）
  Services/        # 核心服务（加密、数据库、剪贴板、截图等）
  Views/           # SwiftUI 视图
  en.lproj/        # 英文本地化字符串
  zh-Hans.lproj/   # 中文本地化字符串
```

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源，Copyright © 2026 DanL。
