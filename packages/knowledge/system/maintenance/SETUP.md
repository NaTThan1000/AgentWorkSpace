# SETUP · 初始化知识库

通过 AgentWorkSpace 接入后，空库 Query 已可直接使用；以下向导只用于独立定制，Agent 可依据已知目标填写参数，不要求用户重复回答。安装记录中的模块目录保持 `modules/knowledge`，不要通过向导改名；首次 Ingest 前补充真实知识范围，并由 Agent 在该模块建立独立本地 Git 基线提交。控制器依赖模块根的 Git 路径，不能直接借用外层根仓；不自动创建远端或推送。原有库沿用自己的历史，不重新初始化。

## 系统要求

- **Windows**：推荐 PowerShell 7（命令 `pwsh`）；仅有 Windows PowerShell 5.1 时也可运行。
- **macOS**：需要安装 PowerShell 7，并在“终端”中确认 `pwsh --version` 可用。安装方式以 [Microsoft 官方 macOS 说明](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos) 为准。

Windows 与 macOS 共用同一套脚本和正斜杠相对路径，不需要修改包内文件。

## 初始化会确认什么

一次性确认：

- 知识库显示名与目标目录名
- 用途、服务对象、重点主题、排除范围、来源标准和默认语言
- 是否启用专家层
- 是否使用 IMA；使用时绑定哪个知识库

## 小白推荐：问答向导

进入复制后的知识库目录，运行：

```powershell
pwsh -NoProfile -File ./system/maintenance/setup-wizard.ps1
```

向导会逐题询问显示名、文件夹名、用途、使用者、重点主题、IMA 和高级设置。每题都会说明“为什么要问”和给出例子，并支持：

- `?`：查看更详细解释。
- `B`：返回上一题。
- `S` 或直接回车：采用推荐值；没有推荐值的必填题会继续提示。
- `Q`：安全退出，不修改任何文件。

第一次使用只需要完成 7 个核心问题。选择“不配置高级选项”时，默认采用：空排除范围、标准来源门槛、简体中文、关闭专家层。IMA 仍会单独询问，避免静默启用或遗漏初始化。

问答完成后，向导会先展示设置摘要并调用底层脚本执行 dry-run。默认选择是“暂不应用”；只有再次确认后才会写入并在最后一步重命名目录。

## 高级用法：直接传参数

从知识库目录的父目录运行。第一次不加 `-Apply`，只查看变更清单：

```powershell
pwsh -File ./knowledge/system/maintenance/initialize-knowledge.ps1 `
  -PackagePath ./knowledge `
  -DisplayName "My Research Wiki" `
  -DirectoryName "my-research-wiki" `
  -Purpose "积累并综合研究资料" `
  -Audience "个人研究" `
  -Topics "主题A","主题B" `
  -ExcludedTopics "纯转载" `
  -SourceQuality "优先一手、可追溯、论证完整的来源" `
  -DefaultLanguage "zh-CN" `
  -UseIma no
```

确认 dry-run 后，用相同参数追加 `-Apply`。脚本先更新包内登记字段，最后才重命名目录；父目录中的引用只报告、不修改。

Windows PowerShell 5.1 可将 `pwsh` 换成 `powershell`，并按本机策略选择是否追加 `-ExecutionPolicy Bypass`；macOS 始终使用 `pwsh`。

维护者也可以准备 UTF-8 JSON 答案文件并运行向导的非交互路径：

```powershell
pwsh -NoProfile -File ./released/system/maintenance/setup-wizard.ps1 `
  -PackagePath ./released `
  -AnswerFile ./answers.json
```

答案文件模式默认仍只 dry-run；确认文件内容后追加 `-Apply`。它用于测试和批量搭建，不是小白默认入口。

## IMA 分支

- 不使用：`-UseIma no`，生成 `status: disabled` 的本地配置。
- 使用但尚未鉴权：`-UseIma yes`，生成 `status: pending_auth`。
- 已选择知识库：追加 `-ImaKnowledgeBaseId` 与 `-ImaKnowledgeBaseName`，生成 `configured_unverified`；只有完成一次真实只读调用后才能改为 `verified`。

问答向导会把这三种状态拆成“不使用 / 以后再配置 / 已有 ID 但未验证 / 已完成真实只读验证”四个可见选项。不要在向导或答案文件中填写密钥、cookie、session token。

本地 IMA 配置被 `.gitignore` 排除，禁止写入密钥、cookie 或 session token。初始化不自动导入 IMA 内容。

## 初始化后的检查

1. 从新目录重新进入。
2. 执行 `system/maintenance/checklists/initialization-check.md`。
3. 运行 `pwsh -File ./system/maintenance/checklists/run-release-contract.ps1`；它会同时调用平台契约和正式树结构检查。
4. 查看脚本报告的包外引用，决定是否单独更新父工作区。
5. 在 `Clippings/` 添加首个来源，或保持空库。

目录名冲突、路径逃逸、控制字符、Windows 保留名和 Windows/macOS 不可移植字符会在任何写入前被拒绝；因此同一实例可在两种系统之间复制。
