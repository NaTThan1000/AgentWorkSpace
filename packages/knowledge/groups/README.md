# Wiki Groups

本目录保存已获制作人批准的 Wiki Group 定义。它是受控知识关系，不是 Domain 的子层级，也不是自由标签集合。

## 运行约束

- 只有 `status: active` 且 `approval_status: approved`、并指向存在审核收据的 Group 可被 Wiki frontmatter 的 `groups` 引用。
- 新建、合并、拆分、重命名和退役先写 Proposal，并取得明确批准；Proposal 不放入本目录。
- Group 必须同时满足：`稳定语义标准 OR 多 Wiki 连接价值`，以及至少一个明确的检索 / 共同阅读用例。
- active Group 必须记录 `reviewed_revision`、`definition_hash`、审核收据和 coverage matrix；它们用于报告何时需要重审，不能由脚本自动补齐成员。
- active Group 的 `candidate_members` 记录仍需维护的 `excluded` / `unresolved` 成员候选；`candidate_review` 指向逐项裁决收据。候选不是成员，不能被 Query 读取或扩张预算。
- `maturity: seed` 可只有一篇成员，但须在两次有效回扫后复核语义依据和 Query 价值。
- 首版不支持 Group 父子层级；Query 也不得沿 Group 递归扩张。
- `## 相关 Wiki 页面` 中由标记包围的成员列表只能由 `sync-wiki-groups.ps1` 写入；成员关系的 SSOT 是 Wiki frontmatter 的 `groups`。

## 术语与覆盖维度

ID、展示名和 alias 全局无歧义。可以作为已有 Group alias 的概念不得重复建立。

覆盖维度使用推荐观察轴：`定义`、`机制`、`体验`、`内容`、`数值`、`表现`、`生产`、`验证`、`批判/风险`。Group 可增加专有维度，但必须在定义页解释其含义。近义覆盖维度只提示归并，不自动改变成员关系。

## 生命周期

1. 在 `system/maintenance/group-proposals/` 写 Proposal。
2. 用 `prepare-wiki-group-review.ps1` 对所有 Wiki 做低成本发现扫描。
3. 对候选、边界项和代表性反例全文裁决，记录 include / exclude / unresolved 与 coverage matrix。
4. 制作人批准后，依据 `group.template.md` 创建本目录中的 Group 文件，写入裁决收据、当前候选成员记录，并在成员 Wiki 写 `groups`。
5. 运行 `sync-wiki-groups.ps1 -Mode Sync` 与 `check-wiki-groups.ps1 -Mode Enforce`。

完整流程见 `docs/superpowers/specs/2026-09-02-wiki-group-governance-and-retrieval-design.md`。

## 查询和消化中的实际使用

Group 提供候选发现信号，不能证明成员正文已读、知识已互证或答案充分。读取多少由当前查询需要与缺口决定，核心 Wiki 读透，补充按需；不按成员数一次全部展开。候选非成员不可因 Group 身份自动扩读，但若另有直接相关证据，可按普通 QUERY_PROTOCOL 的直接发现路径评估，需记录发现路径，不能冒称 Group 授权。

Ingest 在阶段二将既有成员变化、新 Candidate 与不适用的理由合并呈现。自动只记 Candidate 与 review_when，保持已批准定义/成员；没有新批准不提升为运行时 Group。健康检查区分机械漂移与语义重审，只有获准修复范围内同步派生列表，不重写制作人的旧决定。
