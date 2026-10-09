# Raw v2 受控旧批次迁移

入口：`node system/maintenance/checklists/migrate-raw-v2.mjs`。这是显式状态迁移，须有批次重审授权，不是只读升级或最终批准。

仅支持 standalone、schema7、deferred、awaiting_final_review 且 state 同步的运行；其他生命周期不推测迁移。要求来源、Raw、Wiki和本批运行目录已提交，没有外部dirty。旧历史终态不可变。

```text
migrate --run <run.json> --run-hash <actual-sha256> --state-hash <actual-sha256> --baseline <current-full-HEAD> --producer <actual-context-id> --reason <authorized-rework-reason>
checkpoint-base --run <run.json>
recover --run <run.json>
```

默认root为当前工具所属Knowledge，也可显式给 --root。输入哈希来自执行前实际字节，不使用示例值。新生产者必须是真实当前写作者；自动迁移不能产生独立审核通过。

迁移保留原base_revision与counts.before；raw_v2_migration另记录框架集成HEAD作为Stage1差异基线。只接受本批Raw均为原基线后的独立新增且当前总量一致。Wiki最终差异仍从原业务base计算，不隐藏本批早先Wiki写入。

在本批revisions目录保存旧run、数据、收据和报告及state原字节；清空活跃旧content_audits、回测、所有规则依赖包/批准与checkpoint，重开scoring与Stage1及后续段。原评分决定可回读再封装，不能复用旧依赖哈希。来源与正文不改、不删除。

raw-v2-migration.json记录prepared/committed/rolled_back。prepared中断只允许recover在所有当前文件仍等于预期旧/新字节时恢复原字节；有外部编辑必须人工核对，禁止覆盖。已完成或已回滚事务不能再次覆盖。恢复不代表重新认可旧包内容。
若进程被强杀留下锁或migration-tmp，先检查具体文件及原进程是否仍存在，保存证据后只处理已确认的本事务残留；不要删除宽泛目录或启动第二写入者。当前实现不自动清除疑似陈旧锁。

机械测试和副本恢复不替代新Raw独立审核、Stage1/3实际检查或最终用户批准。迁移之后仍须重新写稿、审核和生成新最终哈希。

## 重审中更新框架规则

已迁移批次在用户批准修改规则后，可使用 `advance-checkpoint --run <run.json> --run-hash <实际SHA> --from <框架变更前完整HEAD> --to <当前完整HEAD> --reason <批准范围>` 记录一次框架检查点扩展。只接受 reopened running_scoring、无下游包/提交/最终哈希的 standalone 运行。

from→to 必须仅含检查器、测试、脚本、来源A和明确的Raw README/消化协议；任何来源、Raw正文、Wiki、registry 或运行记录变更都拒绝。先独立提交框架，再记录扩展；原迁移intent、base_revision、counts.before始终不变。扩展证据逐次验证哈希、祖先、精确路径和Raw全集；不放宽 Stage1 路径白名单，不隐藏后续业务差异。写入只涉及一份新证据和原子run更新；若在更新run前中断，新证据是未引用孤件，应核对后恢复，不能把它当成已迁移。
