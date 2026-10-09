# AgentWorkSpace

把这个仓库交给 Agent，告诉它：“在指定目录搭建完整工作区，再加入我需要的模块。”

meta 只有一套完整版。首批业务包为 Brainstorm、F2S 和 Knowledge，按需接入；Agent 处理安装差异，不要求用户选择 meta 组合或填写流程表。能力完整提供，资料与方法按任务读取。

## 从这里开始

发布仓与用户工作区使用不同目录。需要 Python 3.10+ 运行统一工具；业务脚本还需 Node.js 22+、PowerShell 7（Windows 部分脚本可用 5.1）。先预览计划，再应用：

```text
python scripts/workspace.py doctor
python scripts/workspace.py init --target <工作区路径> --packages brainstorm f2s knowledge
python scripts/workspace.py init --target <工作区路径> --packages brainstorm f2s knowledge --apply
python scripts/workspace.py status --target <工作区路径>
```

`--packages` 可以为空或只指定需要的模块；完整 meta 始终安装。以后加入包用 `add`，更新用 `upgrade`，同样默认只预览，加 `--apply` 才写入。只读计划出现 conflicts 时停止依赖写入，保留原数据，由 Agent 带具体差异解决。

## 接入后怎样使用

| 包 | 目标位置 | 开始使用 | 实际初始化边界 |
|---|---|---|---|
| meta | 工作区根 | 直接交代任务 | 完整协作内核、任务方法和空状态入口 |
| Brainstorm | modules/brainstorm | “开始脑暴……” | 按任务创建持久会话；不落盘请求优先 |
| F2S | modules/f2s | “按 F2S 制作原型……” | 在用户指定或独立项目目录创建实际工程；包内文档不是可运行游戏 |
| Knowledge | modules/knowledge | “查询知识库”或“消化材料” | 空库接入即可查询；首次 Ingest 前按真实目标补用途、主题和排除边界 |

接入就是完成框架搭建，业务数据随实际任务产生。Knowledge 原 setup-wizard 保留用于独立使用和可选定制，不要求安装后再重复跑一轮问答。首次 Ingest 前由 Agent 按实际目标补范围，并在 Knowledge 模块建立独立本地 Git 基线（已有库保留历史）；控制器以模块根追踪版本，不能借用外层根仓。不自动创建远端或推送，不能凭空替用户设定知识范围。

用户项目放 `projects/` 或指定目录；会话、知识正文和用户配置留目标实例。不要在本发布仓内填简报、创建会话或维护知识内容。安装记录在 `.agent-workspace/state.json`；它记录框架基线，不拥有用户业务事实。

## 兼容、升级与恢复

当前版本见 [catalog](catalog.json)。每版声明直接前一版，并提供 `upgrades/<版本>.md`：兼容变化、升级步骤、人工冲突及恢复。首版的前身是原三个 released 包，见 [1.0.0 迁移说明](upgrades/1.0.0.md)。未声明的版本跳跃拒绝执行，按发布链逐步升级；不改写已发布 tag。

升级只更新有归属且未被本地改变的框架文件；上游未变的文件保留本地编辑，双方都改动时报告冲突。用户数据不随包替换。每次应用都有事务备份，失败尝试恢复；恢复前也检查后续改动：

```text
python scripts/workspace.py upgrade --target <工作区路径>
python scripts/workspace.py upgrade --target <工作区路径> --apply
python scripts/workspace.py rollback --target <工作区路径> --transaction <事务ID>
python scripts/workspace.py rollback --target <工作区路径> --transaction <事务ID> --apply
```

若异常终止遗留 install.lock，先核对其 PID 和真实进程；确认没有安装操作后由 Agent 保全证据并移除锁，再预览对应事务恢复，不能自动清除另一进程的锁。

## 维护与发布

来源仓继续拥有正文与业务行为；本仓统一交付 meta 和三个 package。修改来源、验证并提交后，用 `scripts/publish.py --source <源仓> --apply` 直接发布所属目录；没有源仓 released 中转。默认只读验证/差异计划，dirty 来源禁止正式 Apply。

发布前运行各来源相关合同、包内独立合同、`python -B -m unittest discover -s tests -v` 和实际包运行验证；写好前一版升级说明，再用 `scripts/build_catalog.py --version <版本> --previous <前版>` 固定库存。`workspace.py verify` 验证实际字节与 catalog 一致。公开 tag 必须对应已验证提交，远端新克隆再次核验。

本仓不包含私人知识正文、会话、画像、运行收据或凭据。公开可见不自动授予额外使用许可；各内容原有授权保持，未明确许可的内容保留作者权利。技术验证不代表创意质量、真实游戏体验、用户验收或跨模型长期效果。
