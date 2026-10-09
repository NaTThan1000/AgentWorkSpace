# raw-sources/ · 源文档

> 层 1：外部权威内容的消化稿——LLM 撰写，用户审核后入库。扁平存放，原则上**不可变**（入库后不再修改）；仅内容回测以原文逐段对照确认遗漏或来源不支持时，按本页“编写规则 #1”的受限例外最小处置。

---

## 文件命名

`<标题>-<来源>-<日期>.md`

- 标题：原文标题（中文保留原文，英文可翻译）
- 来源：发布平台 / 作者（如 GameRes游资网、知乎-王子饼干）
- 日期：原文发布日期（YYYYMMDD）

---

## 格式规范

每个 raw-sources 文件顶部包含 YAML frontmatter：

```yaml
---
source: "来源描述（平台 + 作者）。Clippings 来源时保持纯文本不变"
source_url: "原文 URL（ima知识库来源则填 ima知识库，无则留空）"
source_clipping: "[[Clippings/重命名后的文件名]]（无 .md 后缀）。Clippings 来源时填写，非 Clippings 来源可省略此字段。多 clipping 合并消化时使用 YAML 列表"
date: YYYY-MM-DD
domains: [域1, 域2]     # 所属策划职能域（可多个）
type: article            # article | video | paper | book
tags: [标签1, 标签2]     # 自由标签，辅助检索
ingest_score:
  info_density: 3        # A1 信息密度（0-5）
  argument_quality: 4    # A2 论证质量（0-5）
  time_resistance: 1.00  # A3 时效抗性乘数（×0.85 / ×0.95 / ×1.00）
  intrinsic_total: 8.5   # A 类合计（0-10），自动计算 (A1+A2)×A3_mod，保留一位小数
ingest_verdict: pass     # pass | conditional（🟢 直接消化 | 🟡 条件消化）
---
```

来源信息以 YAML 的 `source`、`source_url`、`source_clipping` 为唯一标记；正文底部不再重复添加 `## 来源` 段或 clipping 链接。

**多 URL 合并消化**：当用户一次提交 ≥2 个 URL 并明确要求合并，或 AI 判断为合并候选且经用户确认后，`source_url` 使用 YAML 列表格式：

```yaml
source_url:
  - "https://example.com/article-part-1"
  - "https://example.com/article-part-2"
  - "https://example.com/article-part-3"
```

> **判据**：同一系列/课程、连续章节、互相引用或共同问题链只构成"合并候选"；AI 必须提出候选与依据，由用户确认后才合并为单 raw。仅同一作者或主题独立 → 各自独立消化。

正文是核心知识完整的中文消化稿：精简叙事枝节和赘语，保留核心观点及必要推理、例子、相关数据与限制，不添加 LLM 个人解读。

每个模块（`##` 二级标题）须标注原文位置：

```markdown
## 一、模块标题
> 📍 原文：文章开头至"×××"部分之前 / 第×~×段

模块正文内容...
```

### 写作与复核标准

唯一内容与文风标准为 [RAW_STANDARD_V2](../system/maintenance/checklists/raw-standard-v2.md)，执行示例见 [写作与审核说明](../system/maintenance/checklists/raw-writing-v2.md)。现行规则 core-semantic-20260910；写前完整阅读并生成全文 manifest，再判断核心观点与必要支撑，不先写摘要再按字数扩写。

本通用实例默认使用 `system/maintenance/checklists/raw-writing-v2.md` 的合成示例；若用户另提供文风样本，绑定实际版本，只借鉴自然段、步骤和比较表按语义混用，不把未经全文回读的样本当内容金标。

自然段承担解释和推理，真实并列/步骤/比较用列表或表格；不强制分点，不设压缩率、段落字数或载体比例门槛。根据删除是否损害理解和论证判断内容必要性，省略理由须经独立复核。Raw 不嵌图：必要图义读图消化，未可靠转录的在对应位置标记；非必要视觉细节可经说明后通过但必须披露。

`check-raw-style.ps1` 默认只执行 v2 格式检查，结果不证明语义完整。日常与回测共用 `raw-quality.mjs` 的全文双向审核核心，分别报告机械检查、独立语义结果及媒体缺口；不得用自填 complete 或 independent_pass 字段冒充真实复核。

### 不可变与辅助记录

入库正文原则上不可变。历史回测先报告，不自动修稿；经授权且原文逐段确认的遗漏/不支持表述才最小补写或原位校正，保留版本与证据，按需复核既有 Wiki，不借机拆分或新建知识结构。历史批注可按既有消费授权清理；新 Raw 从 Stage 1 起不含 AI 批注或来源附录。

AI 意见保存在阶段包辅助记录中，阶段二规划去向，阶段三按批准内容写入 Wiki。正文未被 Wiki 消费的内容按 `system/registry/raw-list.md` 未消费协议登记；不能把登记清单附回 Raw 底部。作者本人的限制和疑问仍应完整保留在正文。

### 历史兼容

旧全文双轴规范、旧风格阈值和历史收据仅用于原版本复验。新运行使用 schema 8 / RAW_STANDARD_V2；不得改写旧批准事实，或用旧审核收据让新批次通过。

---

## 入库流程

1. LLM 读取全部原文并生成不可缺项的 source manifest
2. LLM 以 manifest 为范围基准写消化稿，不先筛“核心内容”
3. 独立语义回读逐单元填写 source→raw 裁决并生成收据；任一失败项先修复再重审
4. 在审核前完成格式与 frontmatter；v2 全文独立审核 passed 后，标准模式交用户阶段审核，自动模式保留同等证据并在 Stage 1 建 checkpoint
5. 经当前模式对应的批准/内部门禁进入归属规划；自动最终报告仍需用户对精确版本批准，技术通过不算验收
6. 入库 raw-sources/ 后按不可变规则保护，后续新理解进入 Wiki
7. 后续提取关键信息写入 wiki（见 `system/protocols/INGEST_PROTOCOL.md` §阶段二·wiki写入审核与 §阶段三·wiki写入和维护）
8. 入库后更新 `system/registry/raw-list.md` 登记表（追加新文件行，引用次数初始=0）

> **文件清单已独立**：raw 文件登记表（引用次数 + 孤立标记）迁移至 `system/registry/raw-list.md`，不再在本文件维护。

## 生成时就防止遗漏

按[完整实作与反例](../system/examples/ingest-content/README.md)执行：先冻结所有来源，再把全部内容单元分配进写作骨架；跨章节的定义与限定建立同组关联。骨架先记录“预计必须保留/待判断”，不提前捏造 coverage_status；正文完成后才记录真实覆盖。

数字保留数值、单位、范围、分母、时间条件与比较基准；相关不改写成因果；作者推测不改写为验证结论。背景若解释方法为何改变，必须进入推导。媒体独立信息无法读取时显式留标，查用时不得凭标记推断图中值。样式调整不改变原义，少一行或多一张表都不是有效性证据。
