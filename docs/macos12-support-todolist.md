# macOS 12 Support Todo List

## 目标

把项目最低支持系统从 macOS 14 降到 macOS 12，同时尽量保持核心体验不回退。

当前这条分支的工作重点已经从“能不能编译”转到“运行时行为是否稳定、能不能真正交付”。

## 当前状态

- [x] 工程 `MACOSX_DEPLOYMENT_TARGET` 已降到 `12.0`
- [x] Xcode 14.2 下已能完成真实编译
- [x] `Observation` 主链路已切到 `ObservableObject` / `@Published` / `@EnvironmentObject`
- [x] 一批较新的 SwiftUI 语法已回退到 macOS 12 可编译写法
- [x] 持久化方案已恢复为真实落盘实现
- [x] GitHub Actions 已能构建 `x86_64 arm64` 通用包
- [x] 本地 `Release` 包已可完成 ad-hoc 签名校验
- [ ] 旧 `Storage.sqlite` 的迁移兼容性还缺真实样本验证
- [ ] 双击 `Option` 唤醒仍需继续实测
- [ ] 预览面板和左侧列表的运行时布局仍需继续实测
- [ ] 缺少 macOS 12 真机或虚拟机回归验证
- [ ] `README` / 发布说明 / 兼容性说明尚未同步

## 已完成的关键改造

### 数据层

- 已从 `SwiftData` 路线切回真实落盘存储
- 默认数据路径继续保持为 `Application Support/Maccy/Storage.sqlite`
- 写回时机已补齐到历史记录、固定项和部分标题更新链路

### 状态管理与界面兼容

- 已把主链路里的 `Observation` 写法替换为 macOS 12 可用方案
- 多处 `@Bindable`、新式环境注入和较新的 SwiftUI API 已做回退
- 入口、设置页和部分系统能力已做条件化降级

### 构建与分发

- 本地和 GitHub Actions 已能构建通用二进制
- 本地 `Release` 产物已验证包含 `x86_64 arm64`
- unsigned 构建下的 Sparkle 报错链路已做降级处理

### 近期运行时修复

- 修复过弹窗初始高度过小的问题
- 修复过预览展开后偶发退化成 footer-only 面板的问题
- 调整过图片项列表样式和右侧预览布局
- 简化过双击修饰键监听链路

## 当前主要阻塞

### 1. 旧数据兼容性还没跑完

- 还没有用真实旧 `Storage.sqlite` 样本验证迁移
- 还缺少对 `pin`、复制次数、首末次复制时间等字段的回归确认

### 2. 旧系统上的运行时行为还不够稳定

- 双击 `Option` 唤醒仍需继续排查
- 预览和列表布局在旧系统下偶发出现尺寸异常
- 还没完成一轮完整的“启动 -> 复制 -> 搜索 -> 选择 -> 设置 -> 重启”链路验证

### 3. 文档和对外说明还没跟上

- `README.md`
- `README.zh-Hans.md`
- 发布说明
- 对 macOS 12 的功能边界说明

## 接下来优先级

1. 先把运行时稳定性补到可连续使用
2. 再做旧数据兼容验证
3. 最后同步 README、发布说明和对外版本信息

## 记录约定

- 每次继续推进这条 macOS 12 兼容线时，都把“本次变更内容 / 下次需要变更的内容 / 验证结果”追加到本文档
- 默认不再记录纯 `git commit` / `git push` 流水，除非某次发布节点需要单独记录 tag 或构建结论
- 旧的重复记录、纯 git 元数据、对当前排障无帮助的内容可以直接精简
- 如果本轮完成了本地构建、替换或移动 `.app` 产物，需要额外记录产物来源路径、目标路径，以及是否已完成替换
- 如果替换目标软件当时正在运行，先结束对应进程，再执行 `.app` 替换，避免目标目录被占用

## 工作日志

### 2026-04-08 阶段汇总

本次变更内容：

- 完成第一轮 macOS 12 兼容主线落地，工程已经可以在 Xcode 14.2 下真实编译
- `Observation` 和多处较新的 SwiftUI 写法已回退到旧系统可编译方案
- 持久化层已恢复为真实落盘实现，不再停留在临时内存桥接

下次需要变更的内容：

- 用真实旧 `Storage.sqlite` 样本验证迁移和兼容性
- 开始做 macOS 12 运行时回归

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy CODE_SIGNING_ALLOWED=NO build` 已通过
- `HistoryItemTests`、`HistoryTests` 已通过

### 2026-04-09 运行时修复汇总

本次变更内容：

- 调整图片历史项和右侧预览布局，避免内容过小或贴边显示
- 修复本地 unsigned 构建里的 Sparkle 更新器报错
- 调整 GitHub Actions 构建流程，补上 ad-hoc 签名校验
- 修复弹窗初始高度、预览展开后偶发塌缩成 footer-only 面板的问题
- 简化双击修饰键监听路径
- 将 `build-local-package/` 加入 `.gitignore`，并清理 `.xcode-tmp/`

下次需要变更的内容：

- 继续实测双击 `Option` 唤醒
- 继续观察预览面板长时间打开后的尺寸稳定性
- 继续恢复 `ConfirmationView.swift` 的“下次不再提示”交互

验证结果：

- `xcodebuild -resolvePackageDependencies -project Maccy.xcodeproj` 已通过
- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `codesign --verify --deep --strict` 已通过
- `lipo -info` 已确认产物包含 `x86_64 arm64`

### 2026-04-09 当前调整

本次变更内容：

- 调整左侧历史列表的布局策略，让 `HistoryListView` 内部滚动区域优先占满可用高度
- 在 `ContentView` 中提升历史列表的布局优先级，并让 footer 按内容高度收缩
- 重写并精简本文档，删除重复流水和纯 git 元数据
- 针对“滚动区域仍然偏小”的反馈，再把左侧中间滚动区改成 `GeometryReader` 驱动的剩余高度分配，避免多余高度留在列表容器空白区

下次需要变更的内容：

- 用最新本地包实测左侧列表在图片项、普通文本项、预览打开三种场景下的滚动高度
- 如果滚动区仍然偏小，下一步优先增加更明确的列表最小高度策略
- 继续追踪双击 `Option` 唤醒问题

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy CODE_SIGNING_ALLOWED=NO build` 已通过

### 2026-04-09 本地交付补记

本次变更内容：

- 补充记录约定：以后只要完成本地构建并把 `.app` 移动到交付位置，都要把来源路径和目标路径记到本文档
- 最近一次本地交付中，已将 `build-local-package/Build/Products/Release/Maccy.app` 移动到 `/Users/opera/Documents/Maccy.app`

下次需要变更的内容：

- 后续每次本地重新打包并替换 `Documents/Maccy.app` 时，同步更新本文档中的交付记录
- 如果目标包来自新的构建目录，也一并写明新来源路径

验证结果：

- `/Users/opera/Documents/Maccy.app` 当前存在

### 2026-04-09 本地构建并替换

本次变更内容：

- 已重新执行本地 `Release` 构建，构建来源路径为 `build-local-package/Build/Products/Release/Maccy.app`
- 已删除旧的 `/Users/opera/Documents/Maccy.app`，并用这次新构建的 `.app` 完成替换
- 已对 `/Users/opera/Documents/Maccy.app` 补做 ad-hoc 签名，避免本地交付包保持未签名状态

下次需要变更的内容：

- 如果继续调样式或功能，下一轮本地构建完成后继续覆盖 `/Users/opera/Documents/Maccy.app`
- 替换后继续实测左侧滚动区域、双击 `Option` 唤醒和预览面板稳定性

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `/Users/opera/Documents/Maccy.app` 当前存在
- `codesign --verify --deep --strict /Users/opera/Documents/Maccy.app` 已通过
- `codesign -dv --verbose=4 /Users/opera/Documents/Maccy.app` 已确认 `Signature=adhoc`
- `lipo -info /Users/opera/Documents/Maccy.app/Contents/MacOS/Maccy` 已确认产物包含 `x86_64 arm64`

### 2026-04-09 滚动区二次调整

本次变更内容：

- 针对“左侧可滚动区域仍然太小”的反馈，继续调整 `HistoryListView` 的垂直布局
- 将中间滚动区改为由 `GeometryReader` 明确承接剩余高度，再让 `ScrollView` 填满该区域，避免窗口高度被留下大块不可滚动空白
- 已基于这次修改重新本地构建，并再次替换 `/Users/opera/Documents/Maccy.app`
- 进一步确认核心问题还包括图片历史项单行高度过大，因此左侧列表即使占满可用高度，实际可见条目数仍然偏少

下次需要变更的内容：

- 继续实测左侧列表是否已经占满可用高度
- 如果仍然不理想，下一步优先直接给左侧内容列增加显式最小高度和 footer 保底高度，而不是继续只调优先级
- 继续验证双击 `Option` 唤醒和预览面板稳定性

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy CODE_SIGNING_ALLOWED=NO build` 已通过
- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `/Users/opera/Documents/Maccy.app` 已完成替换
- `codesign --verify --deep --strict /Users/opera/Documents/Maccy.app` 已通过
- `lipo -info /Users/opera/Documents/Maccy.app/Contents/MacOS/Maccy` 已确认产物包含 `x86_64 arm64`

### 2026-04-09 列表图片项压缩

本次变更内容：

- 把左侧历史列表中的图片项缩略图改回更紧凑的行高策略
- 收小图片项的缩略图高度、宽度和垂直内边距，避免单个图片项占掉过多可滚动区域
- 保留右侧预览区承担大图展示，左侧列表回归“优先多显示几条历史记录”的策略
- 在重新替换 `/Users/opera/Documents/Maccy.app` 前，已先结束运行中的 `Maccy` 进程，避免替换过程再次被目标目录占用

下次需要变更的内容：

- 用最新本地包继续确认图片项、文本项混排时的可见条目数是否明显改善
- 如果还是偏少，下一步直接给左侧列表加“最少可见条目数”对应的最小高度约束

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy CODE_SIGNING_ALLOWED=NO build` 已通过
- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `killall Maccy` 已执行，用于替换前结束正在运行的软件
- `/Users/opera/Documents/Maccy.app` 已完成替换
- `codesign --verify --deep --strict /Users/opera/Documents/Maccy.app` 已通过
- `lipo -info /Users/opera/Documents/Maccy.app/Contents/MacOS/Maccy` 已确认产物包含 `x86_64 arm64`

### 2026-04-09 窗口高度抖动防抖修复

本次变更内容：

- 修复了由于 SwiftUI `MultipleSelectionListView` 懒加载测算与其对应父窗口（`NSWindow`）进行高频变化交互时引起的“尺寸不稳定，一会儿大一会儿小”无限 Layout 死循环问题
- 在 `HistoryListView.swift` 中为 `resizePopupIfNeeded()` 的处理逻辑补充了 250 毫秒的 `Task.sleep` 强制异步消抖时间，并加上了微小像素变化的 `abs(debounced - measured) > 1` 判断阻断死循环。
- 用这版最新修改的代码再次于本地通过了 `xcodebuild -configuration Release` 的 `x86_64` / `arm64` 跨架构构建。
- 将产出最新的 `.app` 文件移动替换更新至 `/Users/opera/Documents/Maccy.app`，并补充了 `--force --sign -` 签名。

下次需要变更的内容：

- 用户通过真实点击 Maccy 托盘图标体验面板的尺寸稳定性，验证当列表中包含长图与纯文本混合时，不再出现任何的上下颤抖或缩起回弹的情况。
- 继续关注并推动验证“双击 `Option` 唤醒”的实测以及兼容旧版数据落盘流程。

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy CODE_SIGNING_ALLOWED=NO build` 成功。
- 面板重新编译且替换成功，`codesign` 通过，`lipo` 检验通用架构通过。

### 2026-04-09 本地构建并替换补记

本次变更内容：

- 按当前工作区代码重新执行本地 `Release` 构建，构建来源路径为 `build-local-package/Build/Products/Release/Maccy.app`
- 在替换前先执行 `killall Maccy`，避免运行中的旧包占用目标目录
- 已删除旧的 `/Users/opera/Documents/Maccy.app`，并用这次新构建的 `.app` 完成替换
- 已对 `/Users/opera/Documents/Maccy.app` 重新补做 ad-hoc 签名

下次需要变更的内容：

- 继续用最新本地包实测面板高度、预览自动打开后的尺寸稳定性
- 如果仍有异常，再继续追查 `Popup` 高度回写和状态栏打开链路

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `killall Maccy` 已执行，用于替换前结束正在运行的软件
- `/Users/opera/Documents/Maccy.app` 当前存在
- `codesign --verify --deep --strict /Users/opera/Documents/Maccy.app` 已通过
- `codesign -dv --verbose=4 /Users/opera/Documents/Maccy.app` 已确认 `Signature=adhoc`
- `lipo -info /Users/opera/Documents/Maccy.app/Contents/MacOS/Maccy` 已确认产物包含 `x86_64 arm64`

### 2026-04-09 双击 Option 修复后本地构建并替换

本次变更内容：

- 基于当前工作区代码重新执行本地 `Release` 构建，构建来源路径为 `build-local-package/Build/Products/Release/Maccy.app`
- 这轮本地交付包含双击 `Option` 权限预检兼容调整，以及设置页对同一策略的同步收口
- 在替换前先执行 `killall Maccy`，避免运行中的旧包占用目标目录
- 已删除旧的 `/Users/opera/Documents/Maccy.app`，并用这次新构建的 `.app` 完成替换
- 已对 `/Users/opera/Documents/Maccy.app` 重新补做 ad-hoc 签名

下次需要变更的内容：

- 用最新本地包继续实测 macOS 12 上双击 `Option` 唤醒是否恢复稳定
- 如果仍有个别机器不生效，下一步优先补监听器启动结果日志，区分 event tap 成功、fallback 成功和两者都失败的情况

验证结果：

- `xcodebuild -quiet -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath build-local-package -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` 已通过
- `killall Maccy` 已执行，用于替换前结束正在运行的软件
- `/Users/opera/Documents/Maccy.app` 当前存在
- `codesign --verify --deep --strict /Users/opera/Documents/Maccy.app` 已通过
- `codesign -dv --verbose=4 /Users/opera/Documents/Maccy.app` 已确认 `Signature=adhoc`
- `lipo -info /Users/opera/Documents/Maccy.app/Contents/MacOS/Maccy` 已确认产物包含 `x86_64 arm64`
