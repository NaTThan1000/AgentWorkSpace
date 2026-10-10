# Packages and optional integrations

中文：四个新包均可独立复制使用；在已有工作区用 compatible 模式可以只选择其中一个，不要求 meta。新建工作区的 full 模式继续安装完整 meta。已有 Brainstorm、FromDemoToSpec 和 Knowledge 的宿主治理要求保持，可由完整 meta 或经过审阅的等价框架提供。

| Package | Core environment | Optional integration | Missing integration |
|---|---|---|---|
| skills | Python 3.10+ to install; Agent to use methods | GAD / Knowledge / GamePresentation for domain routes | Use project facts and available methods; disclose unavailable tools |
| game-analysis-decision | Agent; Node.js 22+ for tools; Git for local learning baselines | Knowledge, Brainstorm, FromDemoToSpec | Direct analysis and project evidence still work; source resolution reports unavailable |
| game-presentation | Agent; Node.js 22+ for transactions; actual Godot for engine verification | PrototypeAssets or reviewed equivalent asset source; GAD; FromDemoToSpec; image generator | Generated/manual sources and workflow remain available; no invented engine/image execution |
| prototype-assets | Node.js 22+ for verify/export | GamePresentation for project update/recovery; FromDemoToSpec for base 2D consumption | List, verify and export remain standalone; copies have no source runtime dependency |

These are capability relationships, not a mandatory package chain. No package automatically installs, downloads, enables or executes another. Root audit recommends only for declared needs, and requires only genuinely missing dependencies. An existing equivalent provider needs actual criteria review and unchanged evidence hashes, not a matching folder name.

安装后：先读 modules/<id>/README.md。自定义宿主入口由宿主维护，不在公开模板中写项目事实。GAD 与 Knowledge 的私有 v2 稳定引用、公开便携 Query 不是同一接口：按实际 Provider 返回状态，或由 Agent 按已安装 Knowledge 当前协议查询并读取材料。缺少原则 Provider 不阻断无关分析。

Godot source flow: approved asset catalog OR generated/manual project sources → project workbench → explicit purpose/rights/technical gates → sealed local release → engine-owned runtime copy. Source catalogs, private prompts and workbench records are not game runtime dependencies. Audit webpage captures are not shipped; original license text and review records remain.

Skills package installation only installs the library. The second, explicit selection step installs named skills into .agents/skills or .codebuddy/skills. Skill state and transactions live in .agent-skills/<platform>, independently of .agent-workspace. A root package upgrade updates the library only; run its skill upgrade command to update already selected skills. If meta and the picker manage the same path, differing changes remain conflicts; do not force either owner's edits over the other.

工程验证不等于专业方法收益、美术/听感认可或真实玩家验收。平台与工具缺失时报告具体限制，继续不依赖它的工作。
