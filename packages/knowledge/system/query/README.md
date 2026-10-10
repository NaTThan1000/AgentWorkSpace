# Query：只读发现、正文读取与证据交付

运行规则由 [QUERY_PROTOCOL](../protocols/QUERY_PROTOCOL.md) 拥有。本目录提供无服务、无数据库的 Node 工具；依赖本仓 `system/integrations/query-principles.mjs`，不需要 GameAnalysisDecision 或父工作区。运行中不写文件、不更新索引／NOW。

## 从实际内容开始

复制 [请求示例](request.template.json) 到已授权宿主或临时目录，填写本题问题；Agent 按上下文补需要与限制，用户不必填这个 JSON。

```powershell
node system/query/query-evidence.mjs discover <request.json> --root <Knowledge根>
```

候选给出 `ref`、标题／章节、来源 hash、发现信号与已探索范围。它们不是已读来源：`content_read:false`。小型中文同义表加 Agent 提供的 `terms/reformulations` 补查；无标题命中时在声明的正文文件预算内查找。`domains/groups/principle_ids/related_from` 按需要加，不要求每个入口都走一遍。

得到相关 ref 后，以以下 JSON 调用 `read`：

```json
{
  "request": {"need": {"question": "当前要回答的问题", "kind": "understanding", "object": "当前项目", "scope": "机制与条件"}},
  "ref": "knowledge:wiki:实际文件名",
  "selection": {"mode": "full"}
}
```

```powershell
node system/query/query-evidence.mjs read <read-input.json> --root <Knowledge根>
```

`ref` 可为 `wiki/实际文件.md`、`raw-sources/实际文件.md`、`domains/实际领域.md`、`Clippings/实际材料.md`，或稳定 `knowledge:wiki:*`／`knowledge:raw:*`／`knowledge:domain:*`／`knowledge:principle:DPR-*`。默认完整正文；完整章节用 `selection:{mode:"section",heading:"准确标题",role:"supplement",reason:"supplement"}`。其它合法章节理由为 `independent_fact`（仅独立事实）、`context_already_read`（上下文真的已读）。核心机制不靠片段代替全文。

每个读取结果带实际 `content`、`source_sha256`、`content_sha256`、`range` 与 `context_sha256`，`claim_support:not_verified`。文件字节读取只是内容返回，Agent 必须真实使用并解释条件；source_kind 原则仍返回精确原则全文和所属 Domain 版本。

## 验证、复用和交给宿主

- `verify` 输入 `{request,receipts:[read结果],citations:[{ref,quote}]}`。校验文件、正文、范围、版本和原句。`evidence_consistent` 不证明语义支持。
- `reuse` 输入 `{request,receipt:先前读取结果}`。字节、权限、问题／对象／范围改变返回 `reuse_invalid`；有效时明确 `source_reused`，仍需 Agent 判断适用性。
- `assemble` 输入 `{request,receipts,claims,gaps,stop_reason}`。`claims` 每项含 `text`、`kind:source_statement|agent_inference`、`applicability`；来源命题需 `evidence:[{ref,quote}]`，引用必须来自实际读取范围。工具校验总来源与字符预算，缺口与停止理由一致；不会自行生成答案或认可内容。

```json
{
  "text": "根据具体来源形成的条件化判断",
  "kind": "source_statement",
  "applicability": "说明对象、阶段和成立条件",
  "evidence": [{"ref": "实际读取结果中的ref", "quote": "读取正文内确实出现的短句"}]
}
```

真实宿主可直接 import `discover, readSource, verifyEvidence, reuseSource, assembleResult`，第二参数是可选库根。所有 CLI 输入均支持 `-` 从 stdin 读取；默认 stdout。测试／宿主可以在自身授权目录保存输出；普通 Query 不自行在本仓创建一份新报告。

`stop_reason` 为 `needs_answered/bounded_discovery_exhausted/budget_exhausted/sources_unavailable/user_scope_reached`。关键缺口未闭合不得宣称 answered；来源身份、推导、未知和用户验收分开。宿主收到 `knowledge_query_result` 后还必须实际使用证据，准备 ContextBrief 不等于这一步。

## 错误与可观察成本

无文件 `missing`、越界 `denied`、权限 `permission_denied`、禁用 `disabled`、媒体 `media_unreadable`、旧或歧义标题 `unavailable`（带原因）、单位超预算 `budget_exhausted`。CLI 非法请求／拒绝／无效证据退出 2；正常缺口仍为可解释结果，调用者检查 `status` 而非仅退出码。

发现阶段为提取标题／章节会读取 Wiki 字节，记录 `metrics.file_reads/bytes_read`；不会声称只扫描文件名。正文补查上限限制词法搜索范围，不能将未查范围说成不存在。返回字符不是 token；当前没有持久缓存，因此也无缓存同步开销。语义召回和正确性由独立效果检查衡量。

行为验证：`node system/query/query-evidence-check.mjs`；在临时库演练，不改真实知识。提供 宿主测试入口 便于总测试入口调用（纯发布包可以只用 Node 检查）。测试成功仅证明所列机械行为。
