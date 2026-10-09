# Knowledge 健康检查与有范围维护

查阅、消化与维护共用知识身份、来源、导航和审核边界。健康检查默认只读；报告不等于修复，不代替内容保真审计、回测或人工决定。

## 实际入口

从 Knowledge 根运行（需要 Node 与 PowerShell）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File system/maintenance/checklists/run-knowledge-health.ps1 -Scope full -Format markdown
powershell -NoProfile -ExecutionPolicy Bypass -File system/maintenance/checklists/run-knowledge-health.ps1 -Scope affected -PreviousReport docs/audits/<task>/health.json -ChangedPath wiki/<page>.md
```

默认输出 JSON 到 stdout，不落日志、不改 NOW/状态/索引。需要留证时由调用者将 JSON 保存到已授权审计目录；`-Format markdown` 输出可读同一结果。`PreviousReport` 必须位于本 Knowledge 内，不接受越界或外部 junction。首次 `affected` 无旧证据会实际执行全部模块。

- 用户主动 Lint/健康检查：默认 affected，明确全面体检用 full。
- Ingest 闭合：`run-ingest-maintenance.ps1` 直接调用同一 `knowledge-health.mjs`；现有阶段检查复用该结果，无重复跑同一工具。标准与自动模式不改变检查质量。
- 融合/拆分：传入实际变化路径，复验来源、跨页链接、导航、Group 与容量；`get-wiki-change-impact.ps1` 保留语义复核队列。
- Query 疑点：只交接来源位置、版本、疑点和所需复核，不在查询时修库。
- 规则/工具升级、未知依赖、漂移难以定位：用 full。此入口不新建或改变任何定时任务。

## 范围与复用

采用**模块级完整依赖复验**，而非只检查 changed files。graph 检查完整 Wiki↔raw↔Domain↔索引；页面链接检查包含反向引用；Group 检查保留全体成员、批准及收据。相关模块任一输入变化便重新全检该模块，因此未改的引用页也能检出断链。

复用必须同时满足：相同工具版本、全部协议/检查工具hash、该模块实际依赖文件集合及字节hash、上次确实执行完成、24小时以内且没有未来时间。规则变动、文件新增/删除/改动、工具失败、过期均失效；full 永不复用。未变模块的旧失败也仍按失败显示，不以复用变成PASS。JSON记录模块fingerprint、依赖目录、输入数、执行时间、退出码和执行/复用区别。

挂账与当前状态每次重新读取，不因工具缓存跳过。历史自然语言 `review_when` 不能由机器宣称未触发：保留原裁决，同时报告待语义复核。不得给旧注册记录补一个当前hash，假装此前裁决适用于新正文。

## 风险与处置

| 检查对象 | 保留的风险检测与本次调整 |
|---|---|
| Wiki结构与相关页 | 标题、页尾来源、编号、链接锚点、重复、相关页说明/镜像；保留已有5/8与300/500检查，不把篇幅当语义质量，不自动增删正文 |
| raw/Clippings身份 | graph核对raw字段、域和引用；迁移hash检查追踪实际Clipping字节。媒体保真仍由来源内容审计，存在链接不等于媒体已读 |
| 来源账本与索引 | source-ledgers Check、graph raw引用计数与index/quick-reference覆盖，不能只改计数制造一致 |
| 跨页锚点与拆分 | link-anchors Check + page/graph 全依赖；唯一可证明修复也须明确写范围。拆分仍要来源去向、导航与实际receipt |
| Domain/Group | 归属双向校验，active与approval、definition hash、review revision、receipt、coverage/candidate/nav；规模和重叠只提示复核，不自动改已批准成员 |
| 语义冲突与挂账 | governance原检测不删；统一报告重新检查延期/闭合的输入与规则绑定、日期/事件、自然语言复核条件，不永久白名单 |
| run/registry/NOW | 当前run与registry核对；摘要疑似待审核语言单列候选，需对照当前段落而非重写历史final review；显式维护才同步 |
| 工具与接线 | 实际运行Query合同、上述当前工具；模块非零/缺失/异常分别保留，执行失败不能伪称内容健康。发布源一致性由发布合同负责 |
| 回测与语义质量 | 继续由Ingest真实触发计划、anchor与content-backtest管理；本报告不把未运行写为通过，也不以健康替代深度/保真复核 |

## 报告、挂账与修复

JSON/Markdown共同输出检查范围与版本、模块实际执行或复用、问题影响、机械事实/语义待复核、owner、建议动作、写权限及未检查项。`incomplete`表示工具未完成，`issues_found`表示机械错误，`needs_review`表示仍有复核事项，`mechanically_healthy`仅指本次机械范围无问题。退出码0表示检查完成（可能需语义复核），2表示机械问题，3表示执行不完整。单项问题只阻断依赖模块/动作。

可选 `system/maintenance/health-issues.json` 只由明确维护任务写入；不为检查自动创建。新挂账记录格式如下，批准语义仍归owner：

```json
{"schema_version":1,"issues":[{"path":"wiki/topic.md","state":"deferred","reason":"具体尚未解决事项","review_when":"下一次该主题来源审核","review_by":"2026-10-01T00:00:00Z","review_events":["source-audit"],"input_hashes":{"wiki/topic.md":"实际SHA256"},"rule_hash":"报告实际rule_hash"}]}
```

`-ReviewEvent source-audit` 显式声明触发事件。日期达到、事件到达、输入或规则改变时恢复为review_required；有效且未到期显示deferred_not_due；resolved/completed仍必须经相同失效检查。缺绑定或仅自然语言的历史记录保持原件并进入复核队列，不能自动升级或废除既有裁决。

修复动作先列真实写范围、owner与恢复点，再执行相应Sync/修复工具，仅由权威源可重建的派生项可在已授权维护范围内更新；正文、共享原则、Group定义及历史审批不自动可写。保留修复前报告，修复后用同入口复验。中断时从恢复点恢复本次范围并确认其他owner数据不变；尚未修复的项继续显式报告。

自动化合同：`tests/knowledge-health.contract.ps1` 在临时副本注入跨页断链、raw域/索引/Group/状态问题，比较affected与full，验证只读、复用失效、挂账到期、工具失败及修复中断恢复。该合同不宣称自然语言语义判断已自动化。

新Wiki、实质内容变更或拆分后，使用 `get-wiki-group-review-scope.ps1` 确定实际增量/完整语义回扫范围，Agent审查候选及边界；发现器不自动批准成员。现行触发与证据失效规则仍按Group合同执行，不因已有机械健康收据跳过必要语义回扫。
