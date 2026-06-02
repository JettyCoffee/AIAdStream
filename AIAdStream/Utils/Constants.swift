import SwiftUI

enum Constants {
    static let pageSize = 10
    static let cardSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let tagSpacing: CGFloat = 8

    struct Colors {
        static let likeActive = Color(red: 0.94, green: 0.72, blue: 0.75)
        static let tagBackground = Color(red: 0.95, green: 0.95, blue: 0.96)
        static let separator = Color(red: 0.93, green: 0.93, blue: 0.94)
        static let secondaryText = Color(red: 0.55, green: 0.55, blue: 0.57)
    }

    static let videoPlayerPoolSize = 3
    static let impressionThreshold: TimeInterval = 1.0

    // MARK: - DeepSeek API

    enum DeepSeek {
        /// 从 Keychain 读取 API Key，未配置时尝试从 UserDefaults 迁移
        static var apiKey: String {
            // 优先从 Keychain 读取
            if let key = try? KeychainService.shared.load(), !key.isEmpty {
                return key
            }
            // 迁移旧版 UserDefaults 中的 Key
            if let legacy = UserDefaults.standard.string(forKey: "deepseek_api_key"), !legacy.isEmpty {
                try? KeychainService.shared.save(legacy)
                UserDefaults.standard.removeObject(forKey: "deepseek_api_key")
                return legacy
            }
            return ""
        }

        static let systemPrompt = """
        你是一个智能广告推荐助手，服务于一款广告信息流 App。你可以使用以下工具：
        - search_ads：根据用户描述搜索匹配的广告
        - get_ad_detail：获取某条广告的详细信息
        - get_similar_ads：查找与某广告相似的其他广告
        - web_search：联网搜索广告相关的补充信息（品牌背景、产品评测、市场行情等）
        - ai_enhance_ad：对广告进行趣味改写，生成幽默段子、诗歌、故事或创意标语

        回复规则（严格遵守）：
        1. 第一次收到用户查询，必须先调用 search_ads 搜索广告
        2. 搜索完成后，广告会以精美的视觉卡片形式自动展示给用户
        3. 你只需在搜索完成后写 1-2 句简洁的推荐总结，例如"这几款都很适合你，第一双透气性尤其好"
        4. 严禁使用任何列表格式（数字编号、Markdown 标题、表格等）逐一列举广告
        5. 严禁重复广告标题、品牌名等已在卡片上展示的信息
        6. 当用户询问某条广告详情时，调用 get_ad_detail 获取完整信息再回复
        7. 当用户询问产品评测、品牌背景、市场对比等需要外部信息的问题时，可调用 web_search 联网搜索补充信息
        8. 当用户点击"趣味解读"按钮时，调用 ai_enhance_ad 生成趣味内容，风格需符合指定 style
        9. 保持回复极简，使用中文
        """

        static let tools: [ToolDef] = [
            ToolDef(
                type: "function",
                function: FunctionDef(
                    name: "search_ads",
                    description: "搜索广告数据库，根据用户需求查找相关广告。返回匹配的广告列表及其基本信息。",
                    parameters: .object([
                        "query": .string(description: "搜索关键词或自然语言描述"),
                        "channel": .string(description: "频道筛选：featured/ecommerce/local，不传则搜索全部"),
                        "limit": .integer(description: "返回数量，默认 5，最大 10"),
                    ])
                )
            ),
            ToolDef(
                type: "function",
                function: FunctionDef(
                    name: "get_ad_detail",
                    description: "获取指定广告的完整详细信息，包括品牌介绍、AI 标签、行动号召等。",
                    parameters: .object([
                        "ad_id": .string(description: "广告的唯一标识 ID"),
                    ], required: ["ad_id"])
                )
            ),
            ToolDef(
                type: "function",
                function: FunctionDef(
                    name: "get_similar_ads",
                    description: "查找与指定广告标签相似的其他广告，用于同类推荐。",
                    parameters: .object([
                        "ad_id": .string(description: "参考广告的 ID"),
                        "limit": .integer(description: "返回数量，默认 3"),
                    ], required: ["ad_id"])
                )
            ),
            ToolDef(
                type: "function",
                function: FunctionDef(
                    name: "web_search",
                    description: "联网搜索广告相关的补充信息，如品牌背景、产品评测、市场行情、竞品对比等。当用户询问需要外部知识的问题时使用。",
                    parameters: .object([
                        "query": .string(description: "搜索查询词，应为简洁的关键词组合"),
                    ], required: ["query"])
                )
            ),
            ToolDef(
                type: "function",
                function: FunctionDef(
                    name: "ai_enhance_ad",
                    description: "对广告内容进行趣味改写。根据广告信息生成幽默段子、打油诗、微型故事或创意标语，让广告变得更有趣、更容易被用户接受。",
                    parameters: .object([
                        "ad_id": .string(description: "广告 ID"),
                        "style": .string(description: "改写风格：funny（幽默段子）/ poetic（打油诗）/ story（微型故事）/ slogan（创意标语），默认 funny"),
                    ], required: ["ad_id"])
                )
            ),
        ]
    }
}
