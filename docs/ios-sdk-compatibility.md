# Xcode 26.3 / iOS 26.2 SDK 兼容性

## 背景
Xcode 26.3 与 iOS 26.2 SDK 中的 MemberImportVisibility 特性要求显式导入 Combine 才能使用 @Published。

## 问题
在未显式导入 Combine 的文件中使用 @Published 会触发编译错误或提示缺失依赖。

## 处理方案
- 在需要使用 @Published 的文件内显式添加 `import Combine`。
- 保持 ViewModel 与依赖声明清晰，避免隐式依赖。

## 设计要点
- 依赖显式化便于编译器诊断与团队协作。
- 兼容性处理应集中在使用处，减少全局污染。
