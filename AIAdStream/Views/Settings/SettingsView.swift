import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showKey = false
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                aboutSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "key")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text("DeepSeek API Key")
                        .font(.system(size: 14, weight: .medium))
                }

                HStack(spacing: 8) {
                    if showKey {
                        TextField("sk-...", text: $viewModel.apiKey)
                            .font(.system(size: 13, design: .monospaced))
                            .focused($isKeyFocused)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("sk-...", text: $viewModel.apiKey)
                            .font(.system(size: 13, design: .monospaced))
                            .focused($isKeyFocused)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // 状态提示
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isKeyValid ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isKeyValid ? "API Key 已配置" : "请输入有效的 API Key（以 sk- 开头）")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("如何获取？")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)

                    Text("前往 platform.deepseek.com → API Keys → 创建新 Key → 复制粘贴到上方输入框")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.blue.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        } header: {
            Text("AI 服务")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                    .font(.system(size: 14))
                Spacer()
                Text("1.0.0")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            .padding(.vertical, 2)

            HStack {
                Text("AI 模型")
                    .font(.system(size: 14))
                Spacer()
                Text("DeepSeek Chat")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            .padding(.vertical, 2)
        } header: {
            Text("关于")
        }
    }
}
