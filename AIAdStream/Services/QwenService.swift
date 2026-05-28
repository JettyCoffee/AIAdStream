import Foundation

/// Qwen 端侧模型服务，将自然语言查询转为结构化标签用于检索
///
/// 当前使用数据库标签词汇模糊匹配作为 fallback。
/// 启用端侧模型：Xcode → File → Add Package Dependencies →
/// 添加 https://github.com/ml-explore/mlx-swift (MLX + MLXLM)，
/// 然后取消下方 #if 块中的注释即可启用 LLM 推理。
final class QwenService {
    static let shared = QwenService()

    private let db = DatabaseManager.shared

    private init() {}

    var isModelReady: Bool {
#if canImport(MLX)
        return modelContainer != nil
#else
        return false
#endif
    }

    // MARK: - Public

    func loadModel() async {
#if canImport(MLX)
        guard !isModelReady, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let fm = FileManager.default
        if !fm.fileExists(atPath: modelURL.appendingPathComponent("config.json").path) {
            print("[Qwen] 模型未下载，开始从 HuggingFace 拉取...")
            await downloadModel()
        }

        do {
            let config = ModelConfiguration(directory: modelURL)
            modelContainer = try await LLM.loadModelContainer(configuration: config)
            print("[Qwen] 模型加载完成")
        } catch {
            print("[Qwen] 模型加载失败: \(error)")
        }
#endif
    }

    func extractTags(from query: String) async -> [String] {
#if canImport(MLX)
        if let tags = await llmExtractTags(query) { return tags }
#endif
        return fuzzyMatchTags(query)
    }

    // MARK: - MLX 推理（需 mlx-swift + mlx-swift-lm SPM 依赖）

#if canImport(MLX)
    private var modelContainer: ModelContainer?
    private var isLoading = false

    private var modelURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Qwen3-0.6B-4bit")
    }

    private let extractionPrompt = """
    你是一个广告标签提取器。给定用户的自然语言搜索查询，提取用于检索广告的中文标签。
    只输出逗号分隔的标签，不要有任何其他文字。每个标签不超过4个汉字。

    示例输入：适合学生党的性价比高的蓝牙耳机
    示例输出：数码,学生党,通勤,音乐

    示例输入：适合上班族的专业办公笔记本电脑
    示例输出：科技,上班族,居家,办公
    """

    private func llmExtractTags(_ query: String) async -> [String]? {
        guard let container = modelContainer else { return nil }
        do {
            let fullPrompt = "\(extractionPrompt)\n输入：\(query)\n输出："
            let result = try await LLM.generate(
                modelContainer: container,
                prompt: .init(role: .user, content: fullPrompt),
                parameters: .init(maxTokens: 50, temperature: 0.1)
            )
            let raw = result.outputs.joined()
            let tags = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count <= 8 }
            guard !tags.isEmpty else { return nil }
            print("[Qwen] 提取标签: \(tags)")
            return tags
        } catch {
            print("[Qwen] 推理错误: \(error)")
            return nil
        }
    }

    private func downloadModel() async {
        let fm = FileManager.default
        try? fm.createDirectory(at: modelURL, withIntermediateDirectories: true)
        let files = ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"]
        let base = "https://huggingface.co/mlx-community/Qwen3-0.6B-4bit/resolve/main"
        for file in files {
            let dest = modelURL.appendingPathComponent(file)
            guard !fm.fileExists(atPath: dest.path),
                  let url = URL(string: "\(base)/\(file)") else { continue }
            print("[Qwen] 下载中: \(file)...")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: dest)
                print("[Qwen] \(file) OK (\(data.count / 1024)KB)")
            } catch {
                print("[Qwen] \(file) 失败: \(error.localizedDescription)")
            }
        }
    }
#endif

    // MARK: - Fallback: 标签词汇模糊匹配

    private func fuzzyMatchTags(_ query: String) -> [String] {
        let allTags = db.allTags(for: nil)
        guard !allTags.isEmpty else { return [] }

        let keywords = extractKeywords(query)
        let scored = allTags.map { tag -> (String, Int) in
            var s = 0
            let tl = tag.lowercased()
            for kw in keywords {
                let kl = kw.lowercased()
                if tl == kl { s += 10 }
                else if tl.contains(kl) || kl.contains(tl) { s += 5 }
                else if levenshteinRatio(tl, kl) > 0.5 { s += 2 }
            }
            return (tag, s)
        }

        let result = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(5).map { $0.0 }
        print("[Qwen] fallback: \(result) ← \"\(query)\"")
        return result
    }

    private func extractKeywords(_ query: String) -> [String] {
        let stopwords: Set<String> = [
            "的", "了", "在", "是", "我", "有", "和", "就", "不", "人",
            "都", "一", "一个", "想", "看", "要", "找", "推荐", "适合",
            "有没有", "哪些", "什么", "可以", "吗", "呢", "啊", "吧"
        ]
        let cleaned = query
            .replacingOccurrences(of: "[，。！？、；：\u{201c}\u{201d}\u{2018}\u{2019}【】（）《》\\s]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.split(separator: " ").map(String.init).filter { !stopwords.contains($0) && $0.count >= 1 }
    }

    private func levenshteinRatio(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1), b = Array(s2), n = a.count, m = b.count
        guard max(n, m) > 0 else { return 1.0 }
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        for i in 1...n {
            for j in 1...m {
                dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] : min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
            }
        }
        return 1.0 - Double(dp[n][m]) / Double(max(n, m))
    }
}
