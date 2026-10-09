# 维护工具

Query工具位于../../query/README.md；消化控制器为ingest-control.ps1；阶段上下文由prepare-ingest-context.ps1提供，包与final review使用同一语义证据。

健康入口为run-knowledge-health.ps1/knowledge-health.mjs，协议见knowledge-health-check.md；run-ingest-maintenance.ps1直接调用并复用该核心。Stage3 用 finalize-ingest-stage3.ps1 的 Prepare/Seal 可重入单入口完成同步、统一暂存、宿主会话自动结算、集中机械门禁、封存和维护；已封存产物只复验。graph/page-health/governance/source-ledgers/link-anchors/capacity/Group/Clipping身份/Query合同仍各自承担实际机械检测。

新Raw使用raw-standard-v2.md、raw-writing-v2.md和raw-quality.mjs；生成与回测同核，缺真实独立审核不通过。旧source-content-audit-standard-v1.md/source-audit-vnext.ps1仅解释历史证据。content-backtest.ps1和build-backtest-anchor-receipt.ps1保持真实触发与证据。Group语义回扫由get-wiki-group-review-scope.ps1指定范围，Agent裁决。

旧批次显式升级见raw-v2-migration.md与migrate-raw-v2.mjs；不得给旧收据换标签。通用零状态库没有私人文风样本时使用raw-writing-v2.md合成示例，不复制私有正文。

默认Check/Report，不因诊断自动Sync正文、原则、Group或历史批准。修复需owner/范围/恢复点并实际复验。包自检使用run-release-contract.ps1。
