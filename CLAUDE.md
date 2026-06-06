## 项目概述
AIAdStream 是一个单列广告信息流 iOS App，使用 SwiftUI + MVVM 架构。支持三种广告卡片样式、频道切换、AI标签过滤、对话式搜索、互动反馈和数据分析。

## 代码
1. 需具有整洁性，不编写冗余代码
2. 代码注释风格要一脉相承
3. 模块按职责分层：Models / Services / ViewModels / Views / Utils
4. ViewModel 使用 @MainActor + ObservableObject + @Published 模式
5. 所有文件如使用 @Published 必须显式添加 `import Combine`（Xcode 26+ MemberImportVisibility 要求）
6. 避免在函数默认参数中引用 MainActor 隔离的静态属性，应在调用处显式传参
7. 卡片组件内部禁止在 body 层使用 `onTapGesture`，会吞噬 NavigationLink 和内部 Button 事件；如需手势用 `highPriorityGesture` 作用于局部区域
8. LazyVStack + NavigationStack 的滚动位置通过 `ScrollViewReader.scrollTo` + `@State lastVisibleAdId` 保留
9. 筛选/加载操作不应同步清空列表数据，应保留旧数据可见 + 顶部加载指示器，数据到达后再替换
10. 媒体区避免使用 `UIScreen.main`（iOS 26 弃用），改用 `aspectRatio` 或 `GeometryReader`
11. 数据库动态 IN 查询使用占位符生成模式：`tags.map { _ in "?" }.joined(separator: ",")`
12. 卡片图片必须使用 `contentMode: .fill` + 深色背景（`.black`），禁止 `.fit`（导致留白白边）
13. 卡片 `cardStyle()` 的 `.clipShape(RoundedRectangle)` 与内层 `.clipped()` 叠加可能产生圆角像素白边，加 `.compositingGroup()` 隔离渲染层
14. 所有背景色必须使用语义化系统颜色（`Color(.systemBackground)`、`.regularMaterial`、`Color(.systemGroupedBackground)`），禁止硬编码 `.white` 或 RGB 值
15. API Key 等敏感凭证存储至 iOS Keychain（`KeychainService`），禁止使用 UserDefaults / `@AppStorage`

## Git 和 文档
1. 每次对话结束后需在 GIT.md 内编写本次修改的摘要，同步给出一个用于 commit 的消息文本
2. commit 消息遵循 conventional commits 格式（feat/fix/refactor/docs）
1. 当你遇到技术难点以独立 .md 文件归档至 docs/，格式：背景 → 问题 → 方案对比 → 最终方案 → 设计要点
2. 每个难点文档需包含至少 2 种方案对比

## UI风格
1. UI 均使用 ios 原生组件
2. UI 以白色系为主，辅以低饱和度的颜色作为各类控件选择
3. 对每类控件的种类选择以及 UI 的位置间距需要谨慎思考
4. 卡片使用 12pt 圆角、16pt 水平内边距、12pt 卡片间距
5. 动画优先使用 spring 弹性动画（response: 0.3, dampingFraction: 0.5）

## Build verify
使用下列指令验证："xcodebuild -project AIAdStream.xcodeproj -scheme AIAdStream -destination 'platform=iOS Simulator,name=iPhone 17' build"

## Claude.md 自进化机制
本文件是项目的核心技能文件，Claude 在每次对话中应：
1. **发现新模式时自动更新**：遇到新的代码规范、架构约定或踩坑经验时，追加到对应章节
2. **修正过时信息**：当项目演进导致旧约定不再适用时，更新或删除对应条目
3. **保持简洁**：每条规则一句话说清，避免冗长解释。规则的 WHY 放在 docs/ 对应文档中
5. **触发自审**：每次对话结束时，检查是否有值得沉淀的新模式，有则更新本文件
