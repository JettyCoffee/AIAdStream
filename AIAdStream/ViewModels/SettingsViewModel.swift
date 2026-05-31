import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @AppStorage("deepseek_api_key") var apiKey = ""

    /// 是否为有效的 API Key（非空且格式大致正确）
    var isKeyValid: Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("sk-") && trimmed.count > 20
    }
}
