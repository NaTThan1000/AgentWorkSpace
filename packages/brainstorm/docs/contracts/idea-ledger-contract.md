# Idea Ledger 合同

## WHAT

Idea Ledger 保存可继续演化、比较或交付的想法。它与 Raw Capture 分层，并通过 Method Runs 追踪方法生成链。

固定列：

| 列 | 合同 |
|---|---|
| Idea ID | `IDEA-###`，会话内唯一 |
| Parent IDs | 逗号分隔的既有 Idea ID；无则 `-` |
| Source | `user / ai-independent / method-generated / project-fact / knowledge / web` |
| Method ID | `method-generated` 必须填 ready method ID；其余必须为 `-` |
| Disposition | `active / merged / parked / rejected / superseded`，回答是否仍保留 |
| Adoption | `none / shortlist / component / package / prototype / later`，回答采用到哪一层 |
| Idea | 非空 |
| Destination | `merged / superseded` 时必须指向另一 Idea；其余可为 `-` |
| Supersedes | 新修订指向一个既有 Idea；无则 `-` |
| Decision reason | `rejected` 必填；修订旧行记录修订原因 |

## WHY

Source 回答“从哪里来”，Method ID 回答“经过哪个已声明认知变换”，Disposition 回答“是否仍保留”，Adoption 回答“采用到哪一层”。四者不可互相替代。`shortlist`、`component` 或 `package` 都不表示已经进入 prototype。

## HOW

- 方法生成的 Idea 必须出现在同 Method ID 的某个 Method Run Output IDs 中。
- Parent IDs 只引用 Idea；原始输入通过 Method Run Input IDs 或 Idea 文本中的明确引用保留。
- Idea 正文一经记录不得原地改写；使用 `revise-session-idea.ps1` 创建新 ID。
- 修订后旧行变为 `superseded / none`，destination 指向新行；新行 `Supersedes` 指回旧行。
- `merged`、`rejected` 和 `superseded` 不得物理删除原行。
- 旧档案中的 `selected` 保留历史原义；活跃新版不接受它，没有旧记录继续运行分支。
- 脚本验证身份、枚举和引用闭合；想法是否优质仍需语义审查。
