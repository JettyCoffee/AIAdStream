# API Key 安全存储：从 UserDefaults 迁移至 iOS Keychain

## 背景

DeepSeek API Key 原通过 `@AppStorage("deepseek_api_key")` 存储在 UserDefaults 中。UserDefaults 数据以 plist 格式明文存储在 App Sandbox 内，虽然受到 iOS 沙箱保护，但在以下场景存在泄露风险：

- 越狱设备可直接读取 plist 文件
- 未加密的 iTunes/Finder 备份包含 UserDefaults 数据
- MDM 工具可能导出应用数据

Apple 在安全白皮书中明确建议使用 Keychain 存储敏感凭证（密码、API Key、Token 等）。

## 方案对比

### 方案 A：使用第三方的 Keychain 封装库

如 `KeychainAccess`（GitHub 13k+ stars），提供 Swift 风格的链式 API。

```swift
let keychain = Keychain(service: "com.app.JettyCoffee.AIAdStream")
keychain["deepseek_api_key"] = apiKey
let key = keychain["deepseek_api_key"]
```

**优点**：
- API 简洁，错误处理完善
- 自动处理 kSecAttrAccessible 等参数

**缺点**：
- 引入外部依赖，增加构建复杂度
- 对于仅需存取一个 Key 的场景属于过度设计
- 第三方库的安全审计成本

### 方案 B：直接使用 Security Framework（采用）

基于 `Security.framework` 的 C API 自行封装，仅需 ~60 行代码。

```swift
final class KeychainService {
    static let shared = KeychainService()
    
    func save(_ value: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func load() throws -> String? { /* SecItemCopyMatching */ }
    func delete() throws { /* SecItemDelete */ }
}
```

**优点**：
- 零外部依赖，仅使用系统框架
- 代码量极小，易于审计和维护
- 完全控制 Keychain 访问策略

**缺点**：
- C API 需要手动管理 CFDictionary 类型转换
- 需要处理 `errSecDuplicateItem`、`errSecItemNotFound` 等状态码

## 最终方案

采用方案 B。设计要点：

1. **访问控制**：使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`，确保设备锁定后 Key 不可读，且不会同步到 iCloud Keychain
2. **存储键**：`service = "com.JettyCoffee.AIAdStream.deepseek_api_key"`，`account = "deepseek_api_key"`，遵循 Apple 推荐的 `BundleID.KeyName` 命名规范
3. **写入策略**：先 `delete` 后 `add`，避免 `errSecDuplicateItem` 错误。`delete` 的 `errSecItemNotFound` 视为正常
4. **迁移策略**：`Constants.DeepSeek.apiKey` 先尝试从 Keychain 读取，失败时回退到 UserDefaults 读取旧 Key，自动迁移并清除 UserDefaults 条目

```swift
static var apiKey: String {
    if let key = try? KeychainService.shared.load(), !key.isEmpty {
        return key
    }
    if let legacy = UserDefaults.standard.string(forKey: "deepseek_api_key"), !legacy.isEmpty {
        try? KeychainService.shared.save(legacy)
        UserDefaults.standard.removeObject(forKey: "deepseek_api_key")
        return legacy
    }
    return ""
}
```

5. **UI 交互**：SettingsViewModel 中 `@Published var apiKey` 从 Keychain 初始化，`.onChange(of:)` 监听变化并实时写入 Keychain

## 踩坑记录

- `@AppStorage` 不能直接替换为 `@Published`，因为 `@AppStorage` 自动同步 UserDefaults。改用 `@Published` + 手动 `load()`/`save()` 模式
- Keychain 在模拟器上可用，但 CI 环境需确保 keychain 已解锁（`security unlock-keychain`）
- `SecItemAdd` 重复添加会返回 `errSecDuplicateItem`，必须先用 `SecItemDelete` 清理
