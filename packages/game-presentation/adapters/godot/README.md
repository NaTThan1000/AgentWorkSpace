# Godot 资源交付

Node.js 22+。可选来源：PrototypeAssets 包，或遵守 catalog/assets.json、catalog/sources.json、素材许可收据和哈希合同的目录。工程上级需要 maintenance/project-config.json，engine.directory 指向包含 project.godot 的目录；新项目可使用 scripts/init-project.mjs，已有项目仅补实际需要的配置。

```text
node adapters/godot/deliver.mjs import --source <asset-source> --engine <project>/Engine --bundle sample --id <asset-id>
node adapters/godot/deliver.mjs import --source <asset-source> --engine <project>/Engine --bundle sample --id <asset-id> --apply
node adapters/godot/deliver.mjs rollback --engine <project>/Engine --bundle sample
node adapters/godot/deliver.mjs recover --engine <project>/Engine --bundle sample
```

import 是完整期望 ID 集合，更新时移除未列出的旧受管资产；不要当增量追加。默认预览，apply 才写。资源和许可证据复制进 Engine/assets/vendor/<bundle>；回退与恢复日志在 maintenance/asset-deliveries/<bundle>。收据、许可、哈希和当前目标所有权均须匹配；未知 ID、许可缺失、禁止分发、越界、符号链接、同名冲突或人工改动均阻断。重复导入无变化。

外部素材不是必需项。生成或手工 PNG 从 [两段工作台](workbench.md) 进入；工具没有自动生成图片、改变 Godot 节点或授予采用资格。格式可接收 PNG/WAV/OGG/TTF/OTF，实际实例范围见 [README](../../README.md)。运行时不依赖来源包。真实引擎导入、显示/播放、实际构建及断开来源后的运行需要单独验证。
