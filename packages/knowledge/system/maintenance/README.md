# maintenance · 维护流程

任何知识库写入完成后：

1. 检查受影响 raw / Wiki / domain 是否符合各自 README 和模板。
2. 更新 `../registry/raw-list.md`、`../registry/index.md`、`../registry/quick-reference.md` 和 `../registry/KNOWLEDGE_STATUS.md` 的派生状态。
3. 运行相关 `checklists/` 与 PowerShell 回归脚本。
4. 更新本目录 `CHANGELOG.md`，再按根 `NOW.md §维护规则` 替换当前快照、焦点、下一步和尾巴；不得追加历史。
5. 检查敏感信息、编码、链接和 Git diff。
6. 所有问题落为“修复 / 挂账 / 明确不处理”之一。

Ingest 一律通过 `checklists/ingest-control.ps1` 创建批次运行清单；普通/自动策略共用阶段包、回测和 `run-ingest-maintenance.ps1` 收据。批次证据与文章反向索引保存在 `ingest-runs/`，实例历史不得复制到新的发布包。

目录增删改时同时更新根 README 的最终目录结构与 `../protocols/RUNTIME_ROUTING.md` 的消息分发，并运行发布契约；不再维护第二份目录树参考。Lint 默认只报告，用户确认后才修复。
