# 项目工具 · v2

当前实测宿主：Node.js v24.15.0、Windows PowerShell 5.1。工具不调用模型、不联网、不写 Knowledge；夹具检查不代表真实玩法或工程模板已通过。

## 初始化

从 FromDemoToSpec 源目录运行：

```powershell
node scripts/prototype-project.mjs init --project E:/AstraGameLab/MyGame --name MyGame --path single-file
node scripts/prototype-project.mjs init --project E:/AstraGameLab/MyGame --name MyGame --path single-file --apply
```

`--path` 可选 single-file 或 maintained-project。默认只打印计划；`--apply` 创建 project-entry.md、design-baseline.md、decisions-and-issues.md、verification-and-delivery.md 与 project-state.json。先完整检查已有目标文件，拒绝覆盖；不创建游戏代码，不执行构建，不能把文档初始化称为引擎模板可用。用户指定已有项目时先检查其入口，能复用则不强制再初始化四份文档。

可持续工程允许先初始化文档整理选择，但实现开始前必须明确正式环境。production-slice.md 与 presentation-calibration.md 按需使用，不默认全部生成。

## 状态与证据检查

```powershell
node scripts/prototype-project.mjs check-state --project E:/AstraGameLab/MyGame
```

默认只读 project-state.json；可用 `--state <项目内相对路径>` 指定另一份。退出0表示声明与可访问文件通过检查；退出2表示合同／IO／输入失败，错误写 stderr。不会自动升级状态、填写认可、关闭问题或接受交付。

project-state.json 由 Agent 根据真实来源维护，是给机器检查的索引，不是第二份产品决定权威。底稿、用户决定与证据拥有其事实；发生冲突先处理，不能修改 JSON 让检查器满意。

| 字段 | 形状与消费方式 |
|---|---|
| schema_version / project_name / lifecycle / stage | 2；名称；两路径之一；internal、v1、ninety-plus、delivered |
| build | id、implementation_started、artifact（file、sha256）；V1以上必须有实际构建与产物引用 |
| environment | platform、engine、engine_version、language、build_command、run_command、input；可持续路径实现前均须明确 |
| evidence[] | 唯一id、build_id、environment、scenario、expected、actual、operator、method、result、file、sha256 |
| checks | scope、core-loop、operation、presentation、reliability、traceability各引用证据ID；90+另需handoff-ready |
| issues[] | id、type、status；closed需resolution与evidence_ids；体验问题可标major |
| recognition | 默认为pending；recognized时必须声明actor=user、subject=core-gameplay、quote、source_ref、recorded_at、scope、build_id和本地用户记录file/sha256 |
| handoff | accepted时需receiver、source_build、steps、next_production_step；多文件另需change_purpose、change_diff（file、sha256） |
| limitations | 实际未覆盖、未知与限制的文字数组；不能用空数组证明没有限制 |

证据result为passed、failed或not-run。引用的通过证据须覆盖当前build.id；复用旧证据要提供reuse.for_build、reason、项目内impact_ref。旧认可复用同理，用户关键体验已变时不得靠填写理由保留认可。

V1 的证据方法集合必须包含runtime-input与full-loop-play；表现证据的aspects须覆盖understanding、feeling、coherence。其余method按实际方法描述。交付steps引用method为reception-run、reception-baseline-review（单文件），或reception-build、reception-run、reception-change、reception-regression（多文件）的证据；operator须对应receiver。

所有本地证据引用都要存在、哈希吻合并留在项目内，拒绝路径穿越或链接越界。用户来源可为会话引用，本地记录保留实际原话及来源；不能把示例用户或Agent判断当真实认可。

**检查器无法判断记录是否忠实，也无法证明实际听感、玩法价值或真实用户身份。** 输出始终保留semantic_review=required、user_recognition_verified=false、actual_play_quality_verified=false。宿主必须核对可信会话与记录的意思。填写一个漂亮JSON不产生正式决定。

## 验证工具自身

```powershell
node --test tests/prototype-project.contract.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File tests/presentation-calibration.contract.ps1
```

前者用明确标注的合成夹具验证正反例，后者验证新校准初始化；它们不创建游戏、不消耗真人认可、不证明跨品类80／90+或成本收益。
