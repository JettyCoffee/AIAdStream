import Foundation

/// Qwen 端侧模型服务，将自然语言查询转为结构化标签用于检索
///
/// 集成方式：
/// 1. Xcode → File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift
/// 2. 选择 mlx-swift 和 mlx-swift-lm 两个 package
/// 3. 下载 Qwen3-0.6B 4-bit 量化模型至 App 的 Documents 目录
/// 4. 取消下方 `// import MLXLM` 及相关代码的注释
///
/// 在此之前，fallback 使用数据库标签词汇模糊匹配完成检索。
final class QwenService {
    static let shared = QwenService()

    private let db = DatabaseManager.shared

    private init() {}

    // MARK: - Public API

    /// 从自然语言查询中提取标签列表
    func extractTags(from query: String) async -> [String] {
        // 当 MLX 模型就绪时使用 LLM 推理
        // if let tags = await llmExtractTags(query) { return tags }

        // Fallback：从数据库现有标签词汇中模糊匹配
        return fuzzyMatchTags(query)
    }

    /// 检查模型是否已加载
    var isModelReady: Bool {
        false // 模型就绪后改为 true
    }

    // MARK: - LLM 推理（需 MLX Swift 依赖）

    /*
    import MLXLM

    private var modelContainer: ModelContainer?
    private let modelURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Qwen3-0.6B-4bit")
    }()

    private let extractionPrompt = """
    你是一个广告标签提取器。给定用户的自然语言搜索查询，提取出用于检索广告的标签。
    只输出逗号分隔的中文标签，不要有任何其他文字。

    示例输入：适合学生党的性价比高的蓝牙耳机
    示例输出：数码,学生党,通勤

    示例输入：适合上班族的专业办公笔记本
    示例输出：科技,上班族,居家,数码
    """

    func loadModel() async {
        guard !isModelReady else { return }
        do {
            let config = ModelConfiguration(directory: modelURL)
            modelContainer = try await LLM.loadModelContainer(configuration: config)
        } catch {
            print("[Qwen] Model load failed: \(error)")
        }
    }

    private func llmExtractTags(_ query: String) async -> [String]? {
        guard let container = modelContainer else { return nil }
        do {
            let fullPrompt = "\(extractionPrompt)\n\n输入：\(query)\n输出："
            let result = try await LLM.generate(
                modelContainer: container,
                prompt: .init(role: .user, content: fullPrompt),
                parameters: .init(maxTokens: 50, temperature: 0.1)
            )
            let raw = result.outputs.joined()
            return raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch {
            print("[Qwen] Inference error: \(error)")
            return nil
        }
    }
    */

    // MARK: - Fallback: 数据库标签词汇模糊匹配

    private func fuzzyMatchTags(_ query: String) -> [String] {
        let allTags = db.allTags(for: nil)
        guard !allTags.isEmpty else { return [] }

        let keywords = extractKeywords(query)

        // 综合评分：精确匹配 > 包含匹配 > 编辑距离
        let scored = allTags.map { tag -> (tag: String, score: Int) in
            let tagLower = tag.lowercased()
            var score = 0
            for kw in keywords {
                let kwLower = kw.lowercased()
                if tagLower == kwLower {
                    score += 10
                } else if tagLower.contains(kwLower) || kwLower.contains(tagLower) {
                    score += 5
                } else if levenshteinRatio(tagLower, kwLower) > 0.5 {
                    score += 2
                }
            }
            return (tag, score)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0.tag }
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

        return cleaned
            .split(separator: " ")
            .map { String($0) }
            .filter { !stopwords.contains($0) && $0.count >= 1 }
    }

    private func levenshteinRatio(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1), b = Array(s2)
        let n = a.count, m = b.count
        guard max(n, m) > 0 else { return 1.0 }

        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }

        let dist = Double(dp[n][m])
        let maxLen = Double(max(n, m))
        return 1.0 - dist / maxLen
    }
}
