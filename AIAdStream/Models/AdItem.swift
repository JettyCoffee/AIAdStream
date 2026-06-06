import Foundation

// 7 个字段：Identifiable + Codable + Hashable（⽤于 LazyVStack 去重）
// videoURL 是 Optional——只有 VideoCard 才有视频
// tags 是 var——允许 AI ⼯具调⽤结果补充标签
// cardType 决定渲染哪个卡⽚组件

struct AdItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let imageURL: String
    let videoURL: String?
    let cardType: AdCardType
    let channel: Channel
    var tags: [AITag]
    let aiSummary: String
    let sponsor: String

    static func == (lhs: AdItem, rhs: AdItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AdPage: Codable {
    let ads: [AdItem]
    let hasMore: Bool
}
