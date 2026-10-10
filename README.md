# AgentWorkSpace

**简体中文** | [English](README.en.md)

AgentWorkSpace 帮你搭建一个可持续使用的 Agent 工作区。它提供完整的协作规则和常用方法，再按需要接入脑暴、原型、知识、游戏分析、表现制作、精选素材和 Skills。

你可以直接告诉 Agent：

> 在指定目录搭建工作区，加入脑暴、原型开发和知识库。先检查环境和现有文件，给出安装计划，再应用没有冲突的变更。

meta 只有一个完整版，无需选择功能组合。新建工作区默认安装它；已有工作区可以使用兼容模式，复用现有框架，只补当前需要的包与缺失能力。规则和方法随任务读取，不代表每次任务都要跑完整套流程。

## 从这里开始

把本仓克隆或下载到一个独立目录，用户工作区放在另一个目录。统一工具和 Skills 选择安装器需要 Python 3.10+；GAD、GamePresentation、PrototypeAssets 的工具需要 Node.js 22+。Brainstorm、FromDemoToSpec 及部分 Knowledge 工具另需 PowerShell 7，Knowledge 首次 Ingest 还需 Git。本次运行验证在 Windows 完成，其他平台按包内说明检查环境。

在发布仓目录运行，先预览，再应用：

```text
python scripts/workspace.py doctor
python scripts/workspace.py init --target <workspace-path> --packages brainstorm fromdemotospec knowledge
python scripts/workspace.py init --target <workspace-path> --packages brainstorm fromdemotospec knowledge --apply
python scripts/workspace.py status --target <workspace-path>
```

上述默认 full 模式中，`--packages` 可以为空，也可以只写需要的包；meta 始终安装。以后加包用 `add`，升级用 `upgrade`。命令默认只预览，加 `--apply` 才写入；出现 `conflicts` 时先解决具体差异。

## 已有工作区：先审计，再按需接入

如果已有协作规则、知识库或其他模块，先告诉 Agent 当前需要，例如“我现在只需要脑暴，审计现有框架并推荐接入方案”。兼容模式会列出已有能力、推荐的可选项，以及所选包确实缺少的依赖。现有模块经过审阅能够替代依赖时直接复用，不要求安装 meta；候选文件的名称本身不能证明兼容。

```text
python scripts/workspace.py audit --target <workspace-path> --needs brainstorm
python scripts/workspace.py audit --target <workspace-path> --packages brainstorm --profile <reviewed-profile.json>
python scripts/workspace.py init --target <workspace-path> --mode compatible --packages brainstorm --profile <reviewed-profile.json>
python scripts/workspace.py init --target <workspace-path> --mode compatible --packages brainstorm --profile <reviewed-profile.json> --apply
```

Agent 按审计返回的 criteria 审阅现有规则与接口，记录理由、证据路径和哈希，生成 profile；证据变化时重新审阅。缺少必需能力时，可以选择完整 meta，或确认现有替代模块。兼容模式不自动增加包：业务包放 `modules/<id>`，选装 meta 放 `modules/meta`，根规则与首页保持原样。首次使用让 Agent 读取新建的 `agent-workspace-compatibility.md`；自动导航与 Skill 发现仍按实际平台核对。详见[兼容模式说明](docs/compatible-workspace.md)。

## 接入后怎样使用

| 组件 | 安装位置 | 可以怎样交代任务 |
|---|---|---|
| [meta](meta/README.md) | full：根目录；兼容模式：`modules/meta` | 直接说明目标、约束和完成标准 |
| [Brainstorm](packages/brainstorm/README.md) | `modules/brainstorm` | “一起脑暴这个问题……”；会话随任务创建 |
| [FromDemoToSpec](packages/fromdemotospec/README.md) | `modules/fromdemotospec` | “制作一个可玩原型……”；在独立项目目录开发 |
| [Knowledge](packages/knowledge/README.md) | `modules/knowledge` | “查询知识库”或“消化这些材料”；空库也可查询 |

框架接入后即可开始任务，业务内容按实际需要产生。FromDemoToSpec 的包内文档是开发工作流，游戏工程在具体任务中创建。Knowledge 首次 Ingest 前，Agent 要根据真实用途补充知识范围，并在模块内建立独立本地 Git 基线；已有库保留历史，不借用外层仓库，不自动创建远端或推送。原向导保留供独立定制，安装后无需重复问答，也不要改动已登记的模块目录名。

项目可以放在 `projects/` 或你指定的目录。会话、知识正文和用户配置留在目标工作区，不写回本发布仓。`.agent-workspace/state.json` 只记录已装版本和框架文件基线，不拥有业务事实。

meta 还包含 [Humanizer-zh](meta/workspace/.agents/skills/humanizer-zh/SKILL.md)。需要润色中文时，可让 Agent 使用它减少空话、重复和模板化表达，同时保留事实、确定程度和作者声音。它是编辑指导，不是作者身份检测工具；英文说明也应保持同样的准确性。

## 新增包与选择安装 Skill

| 包 | 用途 | 独立使用 |
|---|---|---|
| [Skills](packages/skills/README.md) | 16 项开发、研究、表达与工作流方法，按名字选择安装 | 不需要其他模块；安装库不会自动启用全部 Skill |
| [GAD](packages/game-analysis-decision/README.md) | 有事实依据的游戏问题分析、条件建议与方法校正 | Knowledge 与其他宿主包可选 |
| [GamePresentation](packages/game-presentation/README.md) | 表现规格、资源制作与 Godot 交付、恢复 | 可使用手工或生成来源；素材仓可选 |
| [PrototypeAssets](packages/prototype-assets/README.md) | 119 项有来源和许可记录的精选，以及校验导出工具 | 素材和许可复制后，游戏不依赖来源包 |

已有工作区可以只装所需新包；无需为了可选集成安装 meta 或其他包。新建工作区仍默认使用完整 meta。[依赖与工具环境](docs/package-dependencies.md)说明每个操作实际需要什么。

```text
python scripts/workspace.py audit --target <workspace-path> --needs skills game-analysis presentation assets
python scripts/workspace.py add --target <workspace-path> --packages skills game-analysis-decision game-presentation prototype-assets
python scripts/workspace.py add --target <workspace-path> --packages skills game-analysis-decision game-presentation prototype-assets --apply
python <workspace-path>/modules/skills/scripts/skills.py list
python <workspace-path>/modules/skills/scripts/skills.py install --target <workspace-path> --names systematic-debugging property-based-testing
python <workspace-path>/modules/skills/scripts/skills.py install --target <workspace-path> --names systematic-debugging property-based-testing --apply
```

CodeBuddy 选择安装时加 --platform codebuddy。Skill 的更新和回退单独管理，不会覆盖同名的用户改动；游戏路由方法在没有可选包时仍可按项目事实与可用工具工作。当前工程检查不代表方法长期收益或表现效果已通过用户验收。

## 兼容、升级与恢复

当前版本和组件库存见 [catalog.json](catalog.json)。每版声明直接前一版，并在 `upgrades/` 提供兼容范围、操作步骤和恢复方法。不要改写已发布 tag，也不要跳过未声明的版本。

```text
python scripts/workspace.py upgrade --target <workspace-path>
python scripts/workspace.py upgrade --target <workspace-path> --apply
python scripts/workspace.py rollback --target <workspace-path> --transaction <transaction-id>
python scripts/workspace.py rollback --target <workspace-path> --transaction <transaction-id> --apply
```

升级比较原基线、本地文件和新版内容。双方都改过的文件会报告冲突；上游未变的文件保留本地编辑或删除。用户数据保留，每次应用都有事务备份；回滚也会检查事务后的改动。

从 1.0.0 升级时，`f2s` 包和 `modules/f2s` 迁为 `fromdemotospec` 与 `modules/fromdemotospec`，连同目录内的用户文件一起迁移。旧命令参数和脚本入口保留兼容；旧会话的协议 ID、字段和工件名称不强制改写。详见 [1.1.0 升级说明](upgrades/1.1.0.md)。更早的独立 released 包先按 [1.0.0 迁移说明](upgrades/1.0.0.md) 接入，再逐版升级。

异常终止若留下 `install.lock`，先核对 PID 和实际进程；确认没有安装操作后，保全证据并移除锁，再预览事务恢复。不要自动清除另一进程的锁。

## 维护与发布

正文和业务行为在来源仓维护，再直接发布到本仓所属的 `meta/` 或 `packages/<id>/`。各来源不再为这些公开包生成另一份 released 副本。来源提交后运行 `scripts/publish.py --source <source-path> --apply`；默认只预览，未提交的来源不能正式发布。

发布前验证受影响的来源合同、包内运行和上一版升级，运行 `python -B -m unittest discover -s tests -v`。写好升级说明后，用 `scripts/build_catalog.py --version <version> --previous <previous-version>` 固定库存，再运行 `workspace.py verify`。tag 对应已验证提交，公开后从远端新克隆复核。

中文首页和 [English](README.en.md) 用相对链接切换。更新时同时核对两页的功能、命令、版本、限制和许可；不要只翻译开头，也不要让两种语言描述不同的行为。包内详细文档目前以中文为主。

Knowledge 公开包维护独立便携 framework 2.0 实现，不等同于私有宿主最新 consolidated 控制器。仓库不含私人知识、会话、画像、运行收据或凭据。Humanizer-zh 保留 [MIT 许可及来源记录](meta/workspace/.agents/skills/humanizer-zh/references/UPSTREAM.md)；其他内容原有授权不变，公开可见不自动授予新的许可。工程检查不能代替创意质量、真实游戏体验、用户内容审核或长期效果验证。
