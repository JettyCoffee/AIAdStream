import Foundation

final class AdDataService {
    private var allAds: [AdItem] = []

    init() {
        allAds = generateMockAds()
    }

    func fetchAds(channel: Channel, page: Int, pageSize: Int) async throws -> AdPage {
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...1_200_000_000))
        let filtered = allAds.filter { $0.channel == channel }
        let startIndex = (page - 1) * pageSize
        guard startIndex < filtered.count else {
            return AdPage(ads: [], hasMore: false)
        }
        let endIndex = min(startIndex + pageSize, filtered.count)
        let slice = Array(filtered[startIndex..<endIndex])
        return AdPage(ads: slice, hasMore: endIndex < filtered.count)
    }

    func fetchAd(by id: String) -> AdItem? {
        allAds.first { $0.id == id }
    }

    func allAds(for channel: Channel) -> [AdItem] {
        allAds.filter { $0.channel == channel }
    }

    private func generateMockAds() -> [AdItem] {
        let templates: [(title: String, desc: String, cardType: AdCardType, channel: Channel, sponsor: String, cta: String, videoURL: String?)] = [
            // Featured - big image
            ("Nike Air Max 2026", "全新升级气垫科技，缓震性能提升30%，跑步训练首选装备。轻盈透气鞋面搭配动态飞线，每一步都充满能量。", .bigImage, .featured, "Nike", "立即选购", nil),
            ("Apple Watch Ultra 3", "极限运动专属，49mm钛金属表壳，精准双频GPS定位。续航长达72小时，深潜100米防水。", .bigImage, .featured, "Apple", "了解详情", nil),
            ("Sony WH-1000XM8 降噪耳机", "行业领先降噪技术，30小时超长续航，Hi-Res无损音质。全新设计佩戴更舒适。", .bigImage, .featured, "Sony", "立即购买", nil),
            ("特斯拉 Model 3 焕新版", "零百加速3.3秒，续航715公里，全新内饰设计语言。智能驾驶辅助，重新定义出行。", .bigImage, .featured, "Tesla", "预约试驾", nil),
            ("Dyson V16 无绳吸尘器", "激光探测微尘，智能调节吸力。长达70分钟续航，整机HEPA过滤。", .bigImage, .featured, "Dyson", "限时优惠", nil),
            ("星巴克 2026 夏日限定", "椰香冷萃冰咖啡全新上市，清甜椰汁搭配冷萃咖啡，夏日必备清爽饮品。", .bigImage, .featured, "Starbucks", "立即下单", nil),
            ("大疆 DJI Air 4", "一英寸CMOS，4K/120fps，全向避障，34分钟续航。随身携带的专业航拍。", .bigImage, .featured, "DJI", "探索更多", nil),
            ("优衣库 春夏UT系列", "KAWS联名款重磅回归，全新艺术图案，亲肤纯棉面料。限时发售中。", .bigImage, .featured, "UNIQLO", "抢购", nil),
            ("华为 Mate 80 Pro", "卫星通信3.0，昆仑玻璃面板，XMAGE影像系统。6000mAh超长续航旗舰。", .bigImage, .featured, "Huawei", "了解详情", nil),
            ("Adidas Samba OG 经典回归", "复古足球鞋款，柔软皮革鞋面，生胶外底经典不变。打造城市休闲新风尚。", .bigImage, .featured, "Adidas", "立即购买", nil),

            // Ecommerce - small image
            ("欧莱雅 玻尿酸精华液", "三重玻尿酸深层补水，抚平细纹，72小时持续保湿。适合所有肤质使用。", .smallImage, .ecommerce, "L'Oréal Paris", "限时秒杀", nil),
            ("三只松鼠 坚果礼盒", "每日坚果混合装，精选6种优质坚果，独立小包装锁鲜。健康零食首选。", .smallImage, .ecommerce, "三只松鼠", "立即抢购", nil),
            ("Anker 100W氮化镓充电器", "三口快充，支持PD 3.0协议，30分钟充满iPhone。折叠插脚便于携带。", .smallImage, .ecommerce, "Anker", "领券购买", nil),
            ("ZARA 春夏新款连衣裙", "法式碎花设计，轻薄飘逸面料，收腰显瘦剪裁。多色可选，约会通勤两相宜。", .smallImage, .ecommerce, "ZARA", "查看尺码", nil),
            ("SK-II 护肤精华露 230ml", "神仙水，含超过90%天然活酵母精萃Pitera，改善肌肤五大维度。", .smallImage, .ecommerce, "SK-II", "立即选购", nil),
            ("小米 智能空气炸锅 Pro", "5.5L大容量，360度热风循环，100+云食谱。脱脂健康炸，少油更美味。", .smallImage, .ecommerce, "Xiaomi", "下单", nil),
            ("茅台 飞天53度 500ml", "酱香突出，优雅细腻，酒体醇厚，回味悠长。送礼收藏佳品。", .smallImage, .ecommerce, "贵州茅台", "预约抢购", nil),
            ("LEGO 机械组 布加迪Chiron", "1:8比例，3599颗粒，W16引擎与可动尾翼。成年人拼搭体验。", .smallImage, .ecommerce, "LEGO", "加入购物车", nil),

            // Local - video
            ("海底捞 双人欢聚套餐", "精选肥牛+虾滑+毛肚+蔬菜拼盘，赠送招牌锅底。到店即可享用，无需排队。", .video, .local, "海底捞", "预约", "https://example.com/video1.mp4"),
            ("SKP商场 年中大促", "全场3折起，消费满5000返500。国际大牌美妆护肤限时折扣，错过等一年。", .video, .local, "SKP", "查看商场", "https://example.com/video2.mp4"),
            ("Peloton 线下体验店", "来店体验智能动感单车，专业教练实时指导。免费体验30分钟，满意再入手。", .video, .local, "Peloton", "预约体验", "https://example.com/video3.mp4"),
            ("奈雪的茶 新品上市", "霸气芝士芒果全新升级，新鲜芒果现切现做，厚芝士奶盖。新品尝鲜8折。", .video, .local, "奈雪的茶", "新品尝鲜", "https://example.com/video4.mp4"),
            ("全家便利店 会员日", "每周三会员日，全场便当/饭团/沙拉第二件半价。冷饮买一赠一。", .video, .local, "全家 FamilyMart", "查看门店", "https://example.com/video5.mp4"),
            ("Keepland 新店开业", "智能健身空间，按次付费无年卡捆绑。即日起首节体验课免费，新人享专属优惠。", .video, .local, "Keepland", "免费体验", "https://example.com/video6.mp4"),
            ("蔚来 NIO House 试驾活动", "周末试驾送好礼，体验NIO Pilot智能驾驶。现场订车享电池租用优惠。", .video, .local, "NIO", "预约试驾", "https://example.com/video7.mp4"),
            ("盒马鲜生 海鲜现做", "鲜活波龙现捞现做，大厨现场烹饪，鲜甜Q弹。到店消费满200减30。", .video, .local, "盒马鲜生", "到店消费", "https://example.com/video8.mp4"),
        ]

        return templates.enumerated().map { index, t in
            AdItem(
                id: "ad_\(index)",
                title: t.title,
                description: t.desc,
                imageURL: "mock_image_\(index)",
                videoURL: t.videoURL,
                cardType: t.cardType,
                channel: t.channel,
                tags: [],
                aiSummary: nil,
                sponsor: t.sponsor,
                ctaText: t.cta
            )
        }
    }
}
