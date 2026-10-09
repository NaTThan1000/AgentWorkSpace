# 接入已有工作区 / Integrate an existing workspace

兼容模式先理解当前需求与现有框架，按所选包真正缺少的能力补齐，不把“采用这个仓库”等同于“替换根工作区”。新建工作区仍用 full 模式；meta 仍只有一个完整版，没有恢复零件组合。

Compatible mode adds selected capabilities to an existing workspace. It keeps the host's rules and structure. Full mode remains the default for a new workspace; meta still has one complete edition.

## 审计和选择 / Audit and select

可以直接交代 Agent：“审计这个现有工作区，我现在需要脑暴。说明已有能力、可复用模块、推荐的可选项，以及选定包缺少的必需依赖；先给计划，再应用。”Agent 先读本页，使用只读审计定位材料，再审阅真正影响所需能力的文档与接口，不全盘扫描私人内容。

Ask the agent to audit your current workspace for a specific need, identify reusable capabilities, recommend options and identify missing dependencies of selected packages. The agent reviews relevant host documents and interfaces; discovery alone is not proof of equivalence.

```text
python scripts/workspace.py audit --target <existing-workspace> --needs brainstorm
python scripts/workspace.py audit --target <existing-workspace> --packages brainstorm --profile <reviewed-profile.json>
python scripts/workspace.py init --target <existing-workspace> --mode compatible --packages brainstorm --profile <reviewed-profile.json>
python scripts/workspace.py init --target <existing-workspace> --mode compatible --packages brainstorm --profile <reviewed-profile.json> --apply
```

`--needs` 接受 `collaboration`、`brainstorm`、`prototype`、`knowledge`。它们表达当前需要，不自动安装任何包。`--packages` 是实际选择，可包含 `meta`。没有选择时不创建安装记录。两种模式都默认预览，加 `--apply` 才写入；audit 永远只读，不能与 `--apply` 合用。

`--needs` accepts `collaboration`, `brainstorm`, `prototype` and `knowledge`. Needs drive recommendations, not automatic installation. `--packages` is the actual selection and may include `meta`. Selecting nothing creates no installation state. Audit never writes; other commands preview unless `--apply` is present.

| 审计字段 / Field | 含义 / Meaning |
|---|---|
| `candidates` | 发现的路径与摘要，尚未确认可替代 / Discovered documents and hashes; equivalence is unconfirmed |
| `reuse` | 已审阅的替代模块，或仍与基线一致的已安装组件 / Reviewed substitutes or installed components matching their baseline |
| `recommended` | 根据当前需求推荐的可选组件；`missing_if_selected` 列出选择后需补的能力 / Optional recommendations, including conditional gaps |
| `required` | 已选包真正缺少的能力及可安装选项；可通过现有替代模块消除 / Missing dependencies of selected packages, satisfiable by reviewed existing substitutes |
| `optional` | 选定包的可选跨包接线，不成为必选 / Optional cross-package integrations, never mandatory |

三个业务包需要宿主具备目标与授权、范围与数据、事实与验证、交付与恢复四方面的协作约束，能力 ID 为 `host-governance`。meta 可以提供；其他框架经审阅也可以提供。Knowledge 与 FromDemoToSpec 都不是 Brainstorm 的默认必需依赖；只有实际启用对应接线时才核对协议、工具和授权。安装器不执行现有模块，也不把相同名称视为接口兼容。

Business packages require host governance covering goals and authority, scope and data, facts and verification, and delivery and recovery. Meta or a reviewed existing framework can provide it. Cross-package links remain optional. The installer never executes existing modules or treats a matching name as interface compatibility.

审计材料以 [能力合同](../compatibility.json) 为依据，并随版本封入 catalog。Agent 对照每项 criteria 审阅，记录理由和实际证据路径、SHA-256，形成 profile。摘要可以取自审计结果，但 `assurance`、理由和 checks 只能在审阅后填写；不为消除必选项虚构符合性。

The versioned [capability contract](../compatibility.json) is sealed into the catalog. The agent must review every criterion and record its reason and evidence hashes. A profile is a semantic review record, not a machine certification or grant of authority. Hash checks detect stale evidence; they do not prove the review's reasoning.

示例结构如下；替换真实证据和理由后才能使用：

```json
{
  "schema_version": 1,
  "providers": [{
    "id": "existing-host-rules",
    "capabilities": ["host-governance"],
    "assurance": "reviewed",
    "reason": "Describe how the existing rules cover all four criteria, including any interface limits.",
    "checks": {"host-governance": ["goals-and-authority", "scope-and-data", "facts-and-verification", "delivery-and-recovery"]},
    "evidence": [{"path": "AGENTS.md", "sha256": "REPLACE_WITH_ACTUAL_64_CHARACTER_SHA256"}]
  }]
}
```

也可以登记现有的 brainstorming、prototyping 或 knowledge 能力，满足当前需求时审计会优先列出复用，不推荐重复安装。多个文档共同证明时全部登记；脚本、协议或配置影响判断时也作为证据。证据只能指向工作区内普通文件，拒绝越界、链接、缺失、摘要变化或未覆盖全部 criteria 的记录。未知能力保留为未知，不能默认为等价。

You can also review existing brainstorming, prototyping or knowledge providers to avoid duplicate recommendations. Include every document, protocol or configuration needed for the judgment. Evidence must be ordinary files inside the workspace. Missing, stale, linked, escaping or incompletely reviewed evidence is rejected. Unknown capability remains unknown.

## 安装位置与使用 / Placement and use

业务包仍放 `modules/<id>`；选装 meta 完整放在 `modules/meta`，其中相对链接以该目录为准。根 AGENTS、README、现有规则和模块不被替换。工具生成根目录下的 `agent-workspace-compatibility.md`，列出已装入口与复用证据；如已有同名文件则报告冲突。

发布仓可以位于现有工作区内的独立工具目录，但不能位于所选组件的安装目录或安装记录目录内。不能把用户目标放进发布仓。审计只读，不要求搬动现有仓库。

Packages remain under `modules/<id>`. Selected meta is installed complete under `modules/meta`; its relative links are local to that directory. Root rules and home documents remain intact. The generated `agent-workspace-compatibility.md` links installed components and reused evidence, reporting a conflict if an unrelated file already exists there.

The distribution may live in a separate tools directory inside the existing host, but not inside a selected component or installation metadata. Installation targets cannot be inside the distribution. Read-only audit does not require moving existing repositories.

首次使用时让 Agent 读取这个接入入口与实际所用包的 AGENTS/README。meta 作为当前任务的补充指导，不能取代用户指令与宿主权威。meta 中的 Skill 显式按需读取，不宣称已注册到所有平台。若要自动发现接入入口，Agent 应核对当前平台的读取方式，再按用户授权把引用加入现有导航；安装器不猜测或改写宿主接线。

Ask the agent to read the integration entry and the selected package's AGENTS/README. Meta supplements the host; it does not replace its authority. Skills in scoped meta are loaded explicitly as needed. Automatic discovery depends on the host platform and must be checked before adding an authorized navigation link.

运行工具按所选内容核对：统一安装器需要 Python 3.10+，Brainstorm 需要 PowerShell 7，FromDemoToSpec 需要 Node.js 22+ 与 PowerShell 7，Knowledge 需要二者且首次 Ingest 前需要 Git。本仓 `doctor` 检查完整工具箱；兼容接入不因未选择的包缺工具而要求安装它们。

Check tools for selected components: Python 3.10+ for installation, PowerShell 7 for Brainstorm, Node.js 22+ and PowerShell 7 for FromDemoToSpec and Knowledge, and Git before Knowledge Ingest. `doctor` checks the whole toolbox; an unselected package's tools are not a compatibility dependency.

## 后续与恢复 / Maintenance and recovery

兼容模式和已审阅 provider 保存在同一个 state 中。后续 add/upgrade 自动沿用模式并重新校验证据；可传新版 profile 重新审阅。框架冲突、事务备份、失败恢复与回滚沿用统一工具。无关用户内容不进入基线。两种模式不能就地互换；已有 full 安装不搬家、不重新安装 meta。更早独立 released 包仍走其原迁移链，不冒充兼容安装。

Mode and reviewed providers are persisted in state. Add and upgrade retain the mode and recheck evidence; supply a new profile after re-review when needed. Existing transaction, conflict and rollback protections still apply. Unrelated host data is not owned. Modes cannot be switched in place; existing full installations retain their layout. Legacy standalone releases follow their original migration chain.
