import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showKey = false
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                preferencesSection
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

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
            // 广告偏好导航
            NavigationLink {
                TagPreferenceView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 15))
                        .foregroundColor(.pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("广告偏好")
                            .font(.system(size: 14))
                        Text(viewModel.favoriteTagCount > 0
                            ? "已选 \(viewModel.favoriteTagCount) 个偏好标签"
                            : "未设置")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    Spacer()
                    if viewModel.favoriteTagCount > 0 {
                        Text("\(viewModel.favoriteTagCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pink.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }

            // 自动播放视频
            Toggle(isOn: $viewModel.autoPlayVideo) {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 15))
                        .foregroundColor(.blue)
                    Text("自动播放视频广告")
                        .font(.system(size: 14))
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("偏好设置")
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

            HStack {
                Text("种子广告数")
                    .font(.system(size: 14))
                Spacer()
                Text("450")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            .padding(.vertical, 2)
        } header: {
            Text("关于")
        }
    }
}

// MARK: - Tag Preference Page

struct TagPreferenceView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            if viewModel.favoriteTags.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.blue.opacity(0.6))
                        Text("选择你感兴趣的广告类别，信息流中将优先展示相关内容")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(viewModel.favoriteTags, id: \.self) { tag in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    viewModel.toggleFavoriteTag(tag)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pink.opacity(0.8))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("已选择 (\(viewModel.favoriteTagCount))")
                }
            }

            ForEach(viewModel.tagsGroupedByCategory, id: \.category) { group in
                Section(group.category.displayName) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(group.tags, id: \.id) { tag in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    viewModel.toggleFavoriteTag(tag.name)
                                }
                            } label: {
                                Text(tag.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(viewModel.isFavoriteTag(tag.name) ? .white : .primary.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        viewModel.isFavoriteTag(tag.name)
                                            ? Color.pink.opacity(0.8)
                                            : Constants.Colors.tagBackground
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("广告偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}
