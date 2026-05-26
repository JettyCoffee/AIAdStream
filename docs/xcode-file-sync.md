# PBXFileSystemSynchronizedRootGroup 文件同步

## 背景
Xcode 16+ 引入 PBXFileSystemSynchronizedRootGroup，项目文件支持与文件系统自动同步。

## 问题
沿用旧流程手动编辑 pbxproj 会与新机制冲突，产生重复或不一致条目。

## 处理方案
- 以文件系统为主，避免手动写入 pbxproj。
- 让 Xcode 自动维护工程结构。

## 设计要点
- 自动同步减少维护成本，降低工程文件冲突率。
- 文件组织以清晰目录结构为核心，配合 Xcode 的自动管理。
