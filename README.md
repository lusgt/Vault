# Vault

**中文** | [English](README_EN.md)

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

## 运行环境

- macOS 13 Ventura 及以上
- Xcode 15+（构建）

---

## 构建与运行

使用 Xcode 打开 `Vault.xcodeproj`，选择 `Vault` target 后直接运行。

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

## 数据与安全

- 主密码经 PBKDF2-SHA256（200,000 次迭代）派生密钥
- 内容与元数据分离加密，均使用 AES-256-GCM
- SQLite WAL 模式 + secure_delete
- 剪贴板内容在可配置时间后自动清空，锁定或退出时立即清空

详见 [SECURITY.md](SECURITY.md)

---

## 备份与恢复

- 备份文件为加密二进制格式，保存在本地
- 备份密码与主密码完全独立
- 在设置页面可随时导出或恢复备份

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
