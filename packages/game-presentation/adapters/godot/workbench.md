# Godot 两段交付 · v1

生产者/消费者：<asset-source>或生成输出 → 项目不可变sources → work评审 → 不可变releases → 配置的引擎 assets/project/<bundle>。共用 [旧交付器](deliver.mjs) 的路径、所有权、事务和恢复实现；旧vendor安装不自动迁移。

## 目录

无下级目录。

## 操作

从工作区根运行，以下均默认dry-run，加 --apply 才写。项目路径和源路径换成当前项目；bundle/revision 为小写字母开头的字母数字短横线名称。

```powershell
node modules/game-presentation/adapters/godot/workbench.mjs receive --project <project> --source <asset-source> --bundle <bundle> --revision v1 --id <project-asset-id>
node modules/game-presentation/adapters/godot/workbench.mjs receive-generated --project <project> --source <generation-output-folder> --bundle <bundle> --revision v1 --id <project-asset-id>
node modules/game-presentation/adapters/godot/workbench.mjs seal --project <project> --bundle <bundle> --revision v1 --id <project-asset-id>
node modules/game-presentation/adapters/godot/workbench.mjs publish --project <project> --bundle <bundle> --revision v1
node modules/game-presentation/adapters/godot/workbench.mjs rollback --project <project> --bundle <bundle>
node modules/game-presentation/adapters/godot/workbench.mjs recover --project <project> --bundle <bundle> --revision v1 --phase receive
```

recover的phase支持receive / receive-generated / seal / publish，默认publish。rollback只回退可变的运行安装，sources/releases保留不可变历史；恢复中断不是批准换版本。所有命令不联网、不执行素材脚本、不改游戏配置或玩法。

1. maintenance先登记需求、ID与用途规格。receive以catalog中source.upstream_id（无则id）选共享库，不需要伪造生成资源ID。prepare父级README路由：source类型/bundle、release bundle、引擎assets/project、maintenance/asset-deliveries；目标版本目录内部README由收据拥有，勿预填文件造成owner冲突。
2. receive返回bindings，用常规维护编辑显式接入catalog.source；不自动覆盖已有来源/门/工作版。仅接收有审核资格的外部精选，或保全独立生成来源。无ready/采用推断。
3. work评审后将该用途四门设为有证据的pass，stage=ready。未加工默认source.files[0]；加工时delivery.file={path,sha256}，路径只能在项目sources/work，必须有processing记录，保留source哈希。
4. seal封装该bundle完整的ID集合到新revision。缺用途门、权利、source/spec/证据/媒体哈希则拒绝。相同版本重跑no-op，变动必须新revision。
5. 显式将每项catalog.desired_release设为seal返回的项目相对release.json路径，再publish。编译时复验源、规格和门证据未漂移，消费者一致；引擎从配置解析，不接受另一工程路径。
6. 应用后补实际新增父级路由，日志目录README与.gitignore（仅忽略恢复payload，不忽略源/交付收据）；运行health-check。未安装或回退后的期望差异报告warning，不自动覆盖用户文件或改catalog。
7. 发布到引擎不等于打包：宿主导出必须包含assets/project中运行收据和必要许可；实查PCK和调试/源数据排除。不能沿用只允许assets/vendor的旧include_filter。

事务日志位于maintenance/asset-deliveries/workbench-<phase>-<bundle>[-<revision>]。仅本机恢复副本，可按项目合同忽略JSON；历史丢失使用Git/旧release恢复，不伪造CLI可回退。来源及交付版本的receipt.json拥有文件，snapshot.json/release.json记录语义，不原地格式化或手动换图。恢复保留owner文件，首次中断只清理由本次新文件形成且已为空的叶目录。

## 生成来源与权利

receive-generated读取源文件夹的generation.json：kind=generated，assets每项id、producer、version（未知明确unknown）、完整prompt、references数组、file={path,sha256}。当前只接PNG；引用列表保存用途/授权/哈希，不代表工具上传授权。原始PNG和完整记录只留sources，不进入运行收据。

生成/手工release另需delivery.rights={distribution_allowed:true,basis,evidence:[项目内证据]}，不从工具开源许可或AI生成推导商用。必要公开通知通过delivery.licenses=[{path,sha256}]提供。外部vendor不能改成generated绕过审计；源snapshot的origin.kind必须匹配。

delivery.consumer仅接受filter（linear/nearest/linear-mipmap）、anchor二维归一化坐标、display_size二维非负尺寸、mipmaps布尔值；它是可追溯的消费要求，实际Godot节点/导入设置仍由宿主应用和验证，不声称CLI自动修改导入设置。

全量加工recipe在内部release bindings。运行收据只含operation名称、公开来源、许可、文件哈希、用途、消费要求、release指纹；不含完整提示、私有参考、内部路径、门证据。所有媒体和必要许可复制进引擎，无工作台运行依赖。

## 已验证范围

19项新正反例与原24项交付回归通过；实际PNG/Noto中文字体贯通接收、两版本发布/回退、隐藏工作台后的Godot显示和PCK检查，见两段探针（宿主可选参考，按当前项目入口定位）。首个真实生成地图图已获采用并执行seal/publish、实际包整场与隔离回退，见星弦接入（宿主可选参考，按当前项目入口定位）；整体项目效果未验收。

宿主GameProjects和模板的check-releases随health检查交付绑定/当前门/字节/安装差异。离线合同不可达时拒绝publish，保全/检查仍可用；复制合同需标明只读版本，不能自建第二个可编辑权威源。
