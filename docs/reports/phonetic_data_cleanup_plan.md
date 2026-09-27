# 音标数据清洗方案：129 处误录字符修复设计

> 任务：【重构29】。前置：【重构20】IPA 全量审计发现 `:`（半角冒号，应为 `ː` U+02D0）68 处、`'`（半角撇号，应为 `ˈ` U+02C8）61 处。
> 本文档为**设计方案**，全程只读核验，未对数据库执行任何写操作。

---

## 1. 精确定位

### 1.1 总量核对（只读扫描结果）

| 统计项 | 数值 |
|---|---|
| 误录总处数 | **129**（`:` 68 + `'` 61），与【重构20】完全吻合 |
| 含误录的"词条×字段"记录 | 120 条（`:` 63 条 + `'` 57 条，无一条同时含两种误录） |
| 字段分布 | uk_pron（英音）89 条 / us_pron（美音）31 条 |
| 单字段多次出现的记录 | 8 条（如 northeast `/ˌnɔ:θˈi:st/` 一字段内 2 处 `:`） |
| 同一字段内正误字符混存 | 仅 1 条（yourselves `jɔː'selvz`：已有正确的 `ː`，又有误录的 `'`） |

### 1.2 词书分布与规律判断

**`:`（63 条记录）——分散型，指向共享的上游音标源：**
涉及约 110 本词书，头部集中度低：

| 词书 | 记录数 | | 词书 | 记录数 |
|---|--:|---|---|--:|
| XHPRO8ZJH | 35 | | PRO8HY1W3 | 29 |
| RYDSPRO8 | 29 | | PRO8 | 27 |
| LLYC2027 | 20 | | LLYCKY2026 | 20 |

**`'`（57 条记录）——集中型，指向单一数据源：**
高度集中于三本同系列词书：

| 词书 | 记录数 |
|---|--:|
| LLYCKY2026 | 29 |
| LLYC2027 | 25 |
| MTYKY2025 | 18 |
| （次级）HZBCET4 | 11 |

> **规律结论**：两类误录都不是随机录入错误，而是**上游音标导出器的字符映射缺失**——某批数据源把 Unicode IPA 符号降级成了 ASCII 相似字符（`ː→:`、`ˈ→'`）。`'` 类可定位到一个具体来源（恋练有词系三本书贡献过半）；`:` 类因大量单词被多本词书共享而显得分散，但 PRO8 系密度最高，同样指向少数几个上游包。
>
> 推论：**修复应发生在本仓库的数据资产层**（见第 3 节方案选择）；同时建议向词书生产管线反馈导出器映射表，防止新词书继续引入（超出本任务范围）。

## 2. 抽样对照（before / after）

### 2.1 `:` → `ː`（长音符误录，10 例）

| # | 单词 | 字段 | before | after |
|--:|---|---|---|---|
| 1 | anemia | uk_pron | əˈni:mɪə | əˈniːmɪə |
| 2 | cliche | uk_pron | ˈkli:ʃeɪ | ˈkliːʃeɪ |
| 3 | harbor | uk_pron | ˈhɑ:bə | ˈhɑːbə |
| 4 | vantage | uk_pron | ˈvɑ:ntɪdʒ | ˈvɑːntɪdʒ |
| 5 | nonverbal | uk_pron | nɒnˈvɜ:bəl | nɒnˈvɜːbəl |
| 6 | pseudo | uk_pron | ˈsu:dəʊ | ˈsuːdəʊ |
| 7 | moonlighting | uk_pron | ˈmu:nˌlaɪtɪŋ | ˈmuːnˌlaɪtɪŋ |
| 8 | baby boom | uk_pron | ˈbeɪbɪ ˌbu:m | ˈbeɪbɪ ˌbuːm |
| 9 | installment | uk_pron | ɪnˈstɔ:lmənt | ɪnˈstɔːlmənt |
| 10 | northeast | uk_pron | ˌnɔ:θˈi:st | ˌnɔːθˈiːst |

### 2.2 `'` → `ˈ`（主重音符误录，10 例）

| # | 单词 | 字段 | before | after |
|--:|---|---|---|---|
| 11 | in principle | uk_pron | ɪn 'prɪnsəpəl | ɪn ˈprɪnsəpəl |
| 12 | over and over | uk_pron | 'oʊvər ənd 'oʊvər | ˈoʊvər ənd ˈoʊvər |
| 13 | prefrontal | uk_pron | priː'frʌnt(ə)l | priːˈfrʌnt(ə)l |
| 14 | willfully | uk_pron | 'wilfəli | ˈwilfəli |
| 15 | yourselves | uk_pron | jɔː'selvz | jɔːˈselvz |
| 16 | distressful | uk_pron | dɪ'stresfʊl | dɪˈstresfʊl |
| 17 | standardized | uk_pron | 'stændədaizd | ˈstændədaizd |
| 18 | caloric | uk_pron | kə'lɒrɪk; 'kælərɪk | kəˈlɒrɪk; ˈkælərɪk |
| 19 | underestimation | uk_pron | 'ʌndər,esti'meiʃən | ˈʌndər,estiˈmeiʃən |
| 20 | sequent | uk_pron | 'siːkw(ə)nt | ˈsiːkw(ə)nt |

23 例全样本核验无一例外：`:` 全部出现在元音后作长音符（ni:mɪə、bu:m…）；`'` 全部出现在重音符位置（词首或音节前）。**未发现任何一例两种字符的"合法"用法**。

## 3. 边界分析：直接全局替换有没有误伤风险？

**结论：在本 App 的数据形态下，字段限定的全量替换零误伤；连上下文断言都可以不加，但仍建议加一层防御性校验。**

逐项排查：

| 风险假设 | 核验结果 |
|---|---|
| 英文例句里的正常冒号/撇号被波及？ | ❌ 不会。清洗严格限定 `uk_pron` / `us_pron` 两个字段，例句、释义、单词拼写均不触碰；这两字段的内容经【重构20】全量审计就是封闭音标域（54 字符全集已枚举） |
| 音标内部存在合法的 `:` 或 `'`？ | ❌ 不存在。DJ/KK 音标体系中长音符号只有 `ː`、重音符只有 `ˈ ˌ`；129 处的上下文逐一核验 100% 为 IPA 字符（前后邻字符均属于音标字符集或串边界），0 处例外 |
| 撇号会不会是腭化符 `ʲ`(U+02B2) 或声门塞音 `ʔ`(U+0294) 的代用？ | ❌ 排除。若是，应出现在元音之间或软腭音位置；实测全部处于重音符位置（词首/音节前），且同库其余 17,263 处主重音均用 `ˈ` |
| 正确字符与误录混存导致二次破坏？ | ✅ 安全。REPLACE 只改目标字符，同字段已有的 `ː ˈ`（如 yourselves 的 `jɔː`）不受影响；全库仅 1 条此类混存记录 |
| 半角分号/逗号等分隔符被连带改动？ | ❌ 不会。替换表只有 `{: → ː, ' → ˈ}` 两项，`; , . · ()` 等记谱符号不在映射中 |

**推荐的匹配模式（两层防御）**：

```
第一层（充分条件）：字段限定 —— 只 UPDATE uk_pron / us_pron 两列；
第二层（防御性断言，可选）：仅当目标字符的前后邻字符 ∈ [IPA字符集 ∪ {串边界}] 时替换。
   经扫描，第二层在当前数据上的命中集合与第一层完全相同（120/120），
   属于"未来脏数据再进来时少误伤"的保险丝，实现成本极低。
```

## 4. 实现方案三选一并论证

| 维度 | A 构建期一次性脚本（选它） | B 应用启动时迁移 | C 渲染层显示替换 |
|---|---|---|---|
| 数据一致性 | ✅ 资产即干净数据，所有消费方（UI/搜索/分享/TTS/未来导出）统一受益 | ⚠️ 仅当前设备修复；新装/换机要重跑 | ❌ 只有显示层变好，底层数据持续脏 |
| 运行时代价 | ✅ 零（打包期完成） | ❌ 每次启动检查迁移状态；首启额外解压+写库+校验 | ❌ 每帧渲染做字符串变换，浪费 CPU |
| 实现复杂度 | ✅ 一个独立脚本 + 重打包，可离线复审 diff | ❌ 需迁移版本号、失败回滚态、"迁移中杀进程"等边界 | ⚠️ 改 PhoneticText 及一切音标消费点，散弹式修改 |
| 与既有架构契合 | ✅ 项目本就是构建期产出资产（gz 随包分发），无在线更新通道，B 无存在土壤 | ❌ 与"资产随包、无服务端"架构冲突 | ❌ 违背"数据问题在数据层修"原则 |
| 可复审性 | ✅ before/after 可生成全量 diff 报告入库评审 | ❌ 迁移发生在用户设备上，无法逐条 review | ⚠️ 逻辑进代码库但效果分散 |
| 掩盖上游问题 | ✅ 否——脚本即证据，可反哺词书管线 | ⚠️ 是 | ❌✅ 最严重，永远不用查源头了 |

**选定：方案 A。** 理由浓缩为一句话：本项目词库是随包静态资产、无服务端纠错通道，数据错误理应在数据进入 assets 之前一次性终结；B 把同一错误让每台设备各修一遍还要处理崩溃恢复，C 则是把 bug 翻译成性能税并且污染所有非渲染消费方。

## 5. 方案 A 实现草案（未执行，供复审）

### 5.1 清洗脚本草案（Python，复用【重构20】审计基建）

```python
# tools/cleanup_phonetics.py —— 设计稿，尚未创建
import gzip, shutil, sqlite3, pathlib, hashlib, json, sys

SRC_GZ    = r'D:\claude\work\cn_com_lange\word_app\assets\db\wordbook.db.gz'
OUT_GZ    = r'D:\claude\work\cn_com_lange\word_app\assets\db\wordbook.db.clean.gz'
WORKDIR   = pathlib.Path(tempfile.gettempdir()) / 'phonetic_cleanup'
MAP       = {':': '\u02d0', "'": '\u02c8'}          # 误录 → 正确
FIELDS    = ('uk_pron', 'us_pron')

def sha256(p): ...

# ① 解压到临时目录（原始 assets 不动）
# ② 以 mode=ro 打开，预检：记录误录计数基线（应为 129）、词条总数基线（应为 32154）
# ③ 复制一份 rw 工作副本，连接执行：
#    for field in FIELDS:
#        cur.execute(f"UPDATE words SET {field}=REPLACE({field}, ?, ?)", (bad, good))
#    con.commit()
# ④ 五项校验（任一失败则中止、删除产物、退出码 1）：
#    a. 词条总数不变：COUNT(*) == 32154
#    b. 误录清零：instr 计数 == 0（两个字段 × 两个字符）
#    c. 增量守恒：ː 出现次数 +68、ˈ +61（对照基线差值精确相等）
#    d. 其余 50 个字符的频次逐字符不变（防意外波及）
#    e. 随机抽 30 条生成 before/after 对照，人工目检通过
# ⑤ VACUUM 后重新 gzip → OUT_GZ，打印新旧 sha256 + 校验报告 JSON
# ⑥ 由评审者人工将 OUT_GZ 重命名替换 wordbook.db.gz 并提交 git（替换动作不入脚本，留人工卡点）
```

### 5.2 等价 SQL（供 DBA 式复审核心语句）

```sql
-- 预检基线（期望 129）
SELECT
  (LENGTH(COALESCE(uk_pron,''))-LENGTH(REPLACE(COALESCE(uk_pron,''),':',''))
  +LENGTH(COALESCE(us_pron,''))-LENGTH(REPLACE(COALESCE(us_pron,''),':',''))) AS colons,
  (LENGTH(COALESCE(uk_pron,''))-LENGTH(REPLACE(COALESCE(uk_pron,''),'''',''))
  +LENGTH(COALESCE(us_pron,''))-LENGTH(REPLACE(COALESCE(us_pron,''),'''',''))) AS apostrophes
FROM words;

-- 清洗（仅两个字段、两个映射对）
UPDATE words SET uk_pron = REPLACE(REPLACE(uk_pron, ':', char(0x02D0)), '''', char(0x02C8));
UPDATE words SET us_pron = REPLACE(REPLACE(us_pron, ':', char(0x02D0)), '''', char(0x02C8));

-- 复核（期望 0）
SELECT COUNT(*) FROM words
WHERE instr(COALESCE(uk_pron,''),':')>0 OR instr(COALESCE(us_pron,''),':')>0
   OR instr(COALESCE(uk_pron,''),'''')>0 OR instr(COALESCE(us_pron,''),'''')>0;
```

### 5.3 备份与产物策略

1. **原始资产不动**：脚本只读 `wordbook.db.gz`，产物写到 `.clean.gz` 新文件；由人工确认校验报告后才覆盖替换并 git 提交——git 历史本身即是不可变备份；
2. **双哈希留档**：报告中记录旧/新 gz 的 sha256 与大小，写入本次 PR 描述；
3. **可选冷备**：替换后将原始 gz 附到发布制品或网盘归档一份（约几百 KB 成本），应对极端情况；
4. **校验兜底**：即使脚本缺陷漏改/错改，第 5.1 步④的五项校验会在产物落地前拦截。

## 6. 工作量评估

| 事项 | 估时 |
|---|---|
| 实现 + 自审清洗脚本（含五项校验） | 0.5 人时 |
| 执行清洗 + 出校验报告 + 人工目检 30 条 diff | 0.25 人时 |
| 替换资产 + git 提交 + PR 评审 | 0.25 人时 |
| App 侧回归冒烟（抽查 20 个受影响单词的音标显示；确认字符全集从 54 收缩为 52，即 `:` 与 `'` 从【重构20】审计表中消失） | 0.5 人时 |
| **合计** | **≈1.5 人时（0.2 人天）** |

注：App 代码零改动（PhoneticText 已在【重构13】回退 Inter，Inter 对 `ː ˈ` 覆盖已验证），故无编译/发版负担，随下一次正常发版携带。

## 7. 回滚方案

| 场景 | 操作 |
|---|---|
| 替换后发现数据异常（理论上被五项校验拦截，概率极低） | `git revert` 本次资产提交，`wordbook.db.gz` 瞬间恢复原状；App 端无本地持久化迁移，无需用户侧任何动作，下次启动自动加载旧资产 |
| 清洗引入新的未知字符问题 | 同上 revert；并用【重构20】审计脚本对新 gz 复跑一次定位差异（脚本可直接比对字符频次表） |
| 上游词书更新需要合并 | 清洗脚本幂等（对已干净数据命中 0 处、校验照常通过），可在任意新版 db 上重跑后再合入 |

**回滚成本评级：极低**——单文件二进制资产 + git 版本化 + 无客户端状态残留。

---

*本文档基于 %TEMP%\ipa_audit\ 下只读扫描产物（cleanup_locate/detail/books.json、boundary_stats.json）撰写；数据库原始文件与 assets 目录未被修改，未实际执行任何清洗。*
