# meta-agent-collab · 完整 Agent 工作区框架

本仓维护一套完整的通用协作框架，以及帮助 Agent 在不同环境搭建和维护它的说明。完整提供能力，按任务读取和执行，不提供 A–E 或基础/高级功能组合。

使用者从公开发布仓 [AgentWorkSpace](https://github.com/ZhongTyler/AgentWorkSpace) 开始：先搭建根工作区，再按需接入业务包。搭建规则见 [ai-bootstrap](ai-bootstrap/BOOTSTRAP.md)，运行模板见 [workspace](workspace/README.md)，原理见 [why](why/doc-ecosystem.md)。

根内核负责目标、授权、owner、事实、验证和交付；项目合同负责领域；Skill 提供任务方法。框架存在不代表每轮都执行所有检查，也不授权自动画像、记忆写入、外发或发布。

维护采用当前仓 AGENTS 与用户授权；教学正文不是维护权限源。源内容保持唯一权威，发布目标为 AgentWorkSpace/meta；旧 released 是升级迁移基线，不是新版维护目标。发布机制见[公开发布仓说明](https://github.com/ZhongTyler/AgentWorkSpace#维护与发布)。历史 Git 保存旧教学版，不继续旧组合运行入口。

回流需有可迁移问题、具体依据、消费者和适用边界。技术通过、真实任务效果、用户接受分开；不携带私人工作区的真实内容和决定。
