# 初始化检查

## 身份与范围

- [ ] 小白入口使用逐题问答；每题包含影响解释、例子和推荐值，并支持帮助、返回、默认和退出。
- [ ] 问答结果先进入 dry-run；最终确认默认不应用，退出或拒绝时没有文件变化。
- [ ] `system/registry/KNOWLEDGE_SCOPE.md` 的 `name`、`directory_name` 与实际一致。
- [ ] 根 README、AGENTS 与 NOW 的身份标题一致。
- [ ] `purpose`、`audience`、`topics`、排除范围和来源标准已确认。
- [ ] 旧显示名 / 目录名仅出现在 `system/maintenance/CHANGELOG.md` 的显式历史记录中。

## 目录事务

- [ ] 使用 `pwsh` 在当前系统直接启动；macOS 不依赖 `powershell.exe`、反斜杠路径或 Windows 专属模块。
- [ ] dry-run 在任何写入前列出全部包内修改。
- [ ] 实际目录最后重命名；从新路径重新进入。
- [ ] 目标名不是保留名、控制字符、Windows/macOS 不可移植字符、冲突名或路径逃逸。
- [ ] 父目录引用只报告，未被静默改写。

## IMA

- [ ] 用户明确选择 yes / no。
- [ ] 向导区分禁用、待鉴权、已绑定未验证和已验证；只有真实只读验证后才能选择已验证。
- [ ] `system/integrations/ima-config.local.json` 已生成且被 Git 忽略。
- [ ] 配置不含密钥、cookie、session token 或凭据路径。
- [ ] 未做真实只读验证时状态不是 `verified`。

## 零状态

- [ ] raw / Wiki / domain 为空时 Query 与 Lint 均给出合法结果。
- [ ] 根目录只含正式调度文件；协议、登记表、集成和维护资产均在 `system/`，不存在 docs 或 guides。
- [ ] README 只在进入项目、上下文重置或结构维护时读取；逐消息分发由 `system/protocols/RUNTIME_ROUTING.md` 承担。
- [ ] NOW 固定六节且不超过 45 行；快速快照与详细状态一致。
- [ ] `system/maintenance/checklists/run-release-contract.ps1` 通过。
