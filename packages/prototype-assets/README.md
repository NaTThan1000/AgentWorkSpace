# PrototypeAssets

来源、许可和哈希可追溯的精选素材与受控复制工具。本版包含 119 项现有许可收据明确允许公开分发的资产，基础目录与 Godot 增量分别保留；不含下载缓存、完整原包、限制素材和私人项目。

不依赖 meta、GAD、GamePresentation 或 FromDemoToSpec。Node.js 22+，从包目录查看、核验、按 ID 导出：

```text
node scripts/assets.mjs list
node scripts/assets.mjs verify
node scripts/assets.mjs export --ids <asset-id> --target <new-bundle>
node scripts/assets.mjs export --ids <asset-id> --target <new-bundle> --apply
node --test tests/assets.test.mjs tests/publish-directory.test.mjs
```

导出目标须为空或已属于同一份完全一致导出，默认不写入。素材、实际许可、来源元数据与哈希一起复制，游戏运行不依赖本仓。Godot 项目的更新/回滚可选用 GamePresentation；FromDemoToSpec 可消费导出的基础 2D 素材。审核内容不能替代真实解码、引擎显示、听感或具体用途认可。

外部素材按每项 licenses 中的原许可使用；页面快照仅作审计证据，导出默认只携带许可正文，不将网页快照当素材。新增来源需重新审核，不从已下载推断分发权。运行脚本不联网、不执行素材包程序，未自动下载更多素材。

Windows 目录落盘遇到 EPERM/EACCES/EBUSY 时，最多追加 6 次短暂重试，总等待不超过 1.575 秒；目标在等待中出现、权限持续不足或其他错误仍明确失败，不覆盖另一写入者。
