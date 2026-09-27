# 脚本目录说明

## 活跃脚本

| 脚本 | 用途 |
|---|---|
| `build_full_wordbook.py` | 从原始数据源重建离线词库 `wordbook.db`（books/words/word_books 三表 + 坏行统计日志） |
| `check_apk_signature.py` | 校验 APK 签名方案（V1/V2/V3，解析 APK Signing Block）——原 v1/v2 双版本已合并为此一份 |
| `auto_sync.sh` | 日常自动同步：显式 add（排除签名密钥）→ commit → push，含构建产物与密钥双重防呆 |
| `generate_icon.py` | 生成应用图标 |
| `check_data.py` / `check_words.py` / `inspect_db.py` | 词库数据抽查/巡检 |

## 一次性历史脚本（archive/ 及根目录其余脚本）

`scripts/archive/` 与根目录其余 `apply_*.py` / `build_expanded_wordbook.py` 等为历次
数据修补批次的一次性脚本，**不随发版执行**，保留作修补历史的可追溯记录；
新数据修补请另起新脚本并在此登记，勿复用改旧脚本。
