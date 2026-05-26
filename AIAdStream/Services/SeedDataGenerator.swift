import Foundation

struct SeedDataGenerator {
    static func generate() -> [AdItem] {
        var ads: [AdItem] = []
        ads.append(contentsOf: generateFeaturedAds())
        ads.append(contentsOf: generateEcommerceAds())
        ads.append(contentsOf: generateLocalAds())
        return ads
    }

    private static func generateFeaturedAds() -> [AdItem] {
        let items: [(title: String, desc: String, cardType: AdCardType, sponsor: String, cta: String, video: Bool, tags: [(String, TagCategory)])] = [
            ("Nike Air Max Dn8 动态缓震", "全新Dynamic Air气垫科技，四管加压空气实现无缝过渡。Flyknit鞋面轻盈透气，每一步都充满能量。适合跑步、训练、日常通勤。", .bigImage, "Nike", "立即选购", false, [
                ("运动", .category), ("科技", .style), ("运动爱好者", .audience), ("健身", .scene),
            ]),
            ("Apple Vision Pro 空间计算", "突破性的空间计算设备，将数字内容无缝融入物理世界。超高分辨率显示系统，眼动追踪与手势控制。", .bigImage, "Apple", "预约体验", false, [
                ("数码", .category), ("科技", .style), ("上班族", .audience), ("居家", .scene),
            ]),
            ("Sony Alpha 7R VI 全画幅无反", "6100万像素Exmor R CMOS，AI智能对焦，8K/60p视频录制。专业摄影师与内容创作者的终极选择。", .bigImage, "Sony", "了解详情", false, [
                ("数码", .category), ("科技", .style), ("摄影爱好者", .audience), ("创作", .scene),
            ]),
            ("蔚来 ET9 智能电动旗舰", "全域900V高压架构，续航突破1000公里。NIO Pilot 4.0全场景智能驾驶，零重力行政座椅。", .bigImage, "NIO 蔚来", "预约试驾", true, [
                ("汽车", .category), ("科技", .style), ("上班族", .audience), ("通勤", .scene),
            ]),
            ("Dyson Airstrait 吹风直发器", "全新气流直发技术，无需极热即可拉直头发。保护发质，减少62%热损伤。湿发可用，快速造型。", .bigImage, "Dyson", "限时优惠", false, [
                ("美妆", .category), ("时尚", .style), ("都市丽人", .audience), ("居家", .scene),
            ]),
            ("DJI Mavic 4 Pro 航拍无人机", "哈苏相机加持，4/3 CMOS传感器，4K/120fps慢动作。全向视觉避障，46分钟超长续航。", .bigImage, "DJI 大疆", "探索更多", false, [
                ("数码", .category), ("科技", .style), ("摄影爱好者", .audience), ("旅行", .scene),
            ]),
            ("星巴克 臻选冷萃套装", "来自哥斯达黎加单一产地咖啡豆，冷萃20小时慢速萃取。醇厚口感带有可可与坚果香气。", .bigImage, "Starbucks 星巴克", "立即下单", false, [
                ("餐饮", .category), ("简约", .style), ("上班族", .audience), ("通勤", .scene),
            ]),
            ("特斯拉 Cybertruck 电动皮卡", "超硬30倍冷轧不锈钢外骨骼，装甲玻璃。零百加速2.6秒，牵引力4990kg。未来已来。", .bigImage, "Tesla 特斯拉", "了解详情", true, [
                ("汽车", .category), ("科技", .style), ("户外爱好者", .audience), ("户外", .scene),
            ]),
            ("优衣库 x KAWS 联名UT系列", "全新艺术联名款，纯棉舒适面料，多款限定图案可选。男女同款，打造街头潮流穿搭。", .bigImage, "UNIQLO 优衣库", "立即抢购", false, [
                ("服装", .category), ("时尚", .style), ("学生党", .audience), ("聚会", .scene),
            ]),
            ("Bose QuietComfort Ultra 降噪耳机", "沉浸空间音频，CustomTune智能音场调校。全天佩戴舒适，24小时续航。", .bigImage, "Bose", "立即购买", false, [
                ("数码", .category), ("科技", .style), ("上班族", .audience), ("通勤", .scene),
            ]),
            ("lululemon Align 运动紧身裤", "Nulu面料如奶油般柔软，四面弹力，吸汗速干。瑜伽、健身、日常穿搭全方位适用。", .bigImage, "lululemon", "选购", false, [
                ("服装", .category), ("时尚", .style), ("运动爱好者", .audience), ("健身", .scene),
            ]),
            ("华为 Pura 80 Ultra 影像旗舰", "一英寸超聚光伸缩摄像头，XMAGE影像引擎。卫星通信，昆仑玻璃面板，北斗卫星消息。", .bigImage, "Huawei 华为", "了解详情", false, [
                ("数码", .category), ("科技", .style), ("摄影爱好者", .audience), ("旅行", .scene),
            ]),
            ("Patagonia 环保冲锋衣", "100%再生聚酯纤维，H2No防水透气膜。公平贸易认证，终身维修。保护地球，从一件衣服开始。", .bigImage, "Patagonia", "了解品牌", false, [
                ("服装", .category), ("简约", .style), ("户外爱好者", .audience), ("户外", .scene),
            ]),
            ("LEGO 机械组 兰博基尼 Countach", "1:8比例经典超跑，可动剪刀门+尾翼。1506颗粒，沉浸式拼搭体验。收藏级展示模型。", .bigImage, "LEGO 乐高", "加入购物车", false, [
                ("玩具", .category), ("复古", .style), ("学生党", .audience), ("居家", .scene),
            ]),
            ("Airbnb 特色民宿体验", "全球600万+特色民宿，从树屋到城堡，从沙漠帐篷到冰岛极光小屋。每段旅程都独一无二。", .bigImage, "Airbnb 爱彼迎", "探索房源", false, [
                ("旅行", .category), ("文艺", .style), ("旅行爱好者", .audience), ("旅行", .scene),
            ]),
        ]

        return items.enumerated().map { idx, item in
            let types: [AdCardType] = item.video ? AdCardType.allCases : [.bigImage, .smallImage]
            return AdItem(
                id: "feat_\(idx)",
                title: item.title,
                description: item.desc,
                imageURL: "feat_image_\(idx)",
                videoURL: item.video ? "https://example.com/video/feat_\(idx).mp4" : nil,
                cardType: types.randomElement()!,
                channel: .featured,
                tags: item.tags.map { AITag(id: "feat_tag_\(idx)_\($0.0)", name: $0.0, category: $0.1) },
                aiSummary: nil,
                sponsor: item.sponsor,
                ctaText: item.cta
            )
        }
    }

    private static func generateEcommerceAds() -> [AdItem] {
        let items: [(title: String, desc: String, cardType: AdCardType, sponsor: String, cta: String, tags: [(String, TagCategory)])] = [
            ("SK-II 神仙水 护肤精华露 230ml", "含超过90%天然活酵母精萃Pitera，改善肌肤五大维度。补水保湿、提亮肤色、细致毛孔。", .smallImage, "SK-II", "限时秒杀", [
                ("美妆", .category), ("简约", .style), ("都市丽人", .audience), ("居家", .scene),
            ]),
            ("茅台 飞天53度 500ml 酱香型", "茅台镇核心产区，12987传统酿造工艺，53度经典酱香。酒体微黄透明，酱香突出，回味悠长。", .smallImage, "贵州茅台", "预约抢购", [
                ("食品", .category), ("经典", .style), ("商务人士", .audience), ("送礼", .scene),
            ]),
            ("三只松鼠 坚果大礼包 1818g", "每日坚果混合装，精选6种优质坚果，独立小包装锁鲜。非油炸，无添加，健康零食新选择。", .smallImage, "三只松鼠", "立即抢购", [
                ("食品", .category), ("简约", .style), ("学生党", .audience), ("居家", .scene),
            ]),
            ("Anker Prime 100W 氮化镓充电器", "GAN技术，三口快充，支持PD3.1/PPS协议。30分钟充至80%，折叠插脚便携设计。", .smallImage, "Anker 安克", "领券购买", [
                ("数码", .category), ("科技", .style), ("上班族", .audience), ("通勤", .scene),
            ]),
            ("小米 智能空气炸锅 Pro 5.5L", "360度热风循环，100+云食谱，脱脂健康炸。OLED智能触屏，24小时预约，米家APP远程控制。", .smallImage, "Xiaomi 小米", "立即下单", [
                ("家电", .category), ("科技", .style), ("宝妈", .audience), ("居家", .scene),
            ]),
            ("ZARA 法式碎花连衣裙 2026春夏", "轻盈飘逸面料，V领收腰显瘦剪裁。多色可选，法式田园风，约会通勤两相宜。", .smallImage, "ZARA", "查看尺码", [
                ("服装", .category), ("时尚", .style), ("都市丽人", .audience), ("聚会", .scene),
            ]),
            ("Switch OLED 马力欧赛车同捆版", "7英寸OLED鲜艳屏幕，宽幅可调支架。含《马力欧赛车8豪华版》下载码+3个月Nintendo会员。", .smallImage, "Nintendo 任天堂", "立即购买", [
                ("玩具", .category), ("复古", .style), ("学生党", .audience), ("聚会", .scene),
            ]),
            ("欧莱雅 复颜玻尿酸水光充盈导入精华", "三重玻尿酸深层补水，抚平细纹干纹。法国研发中心配方，适合所有肤质，72小时持续保湿。", .smallImage, "L'Oréal Paris", "限时优惠", [
                ("美妆", .category), ("时尚", .style), ("都市丽人", .audience), ("居家", .scene),
            ]),
            ("戴森 V16 Detect 无绳吸尘器", "激光探测微尘，压电式传感器智能调节吸力。LCD屏幕实时显示清洁数据，70分钟续航。", .smallImage, "Dyson 戴森", "查看详情", [
                ("家电", .category), ("科技", .style), ("宝妈", .audience), ("居家", .scene),
            ]),
            ("完美日记 动物眼影盘 12色", "小鹿盘圣诞限定，12色搭配随心变换。细腻粉质显色度高，不易飞粉。新手友好。", .smallImage, "完美日记", "加入购物车", [
                ("美妆", .category), ("时尚", .style), ("学生党", .audience), ("聚会", .scene),
            ]),
            ("MUJI 超声波香薰机", "简约设计，静音运行，4小时定时。搭配MUJI精油，营造温馨舒适空间。", .smallImage, "MUJI 无印良品", "立即选购", [
                ("家居", .category), ("简约", .style), ("文艺青年", .audience), ("居家", .scene),
            ]),
            ("HARIO V60 手冲咖啡套装", "日本制造，锥形滤杯设计，均匀萃取。赠送100张滤纸+600ml玻璃分享壶。", .smallImage, "HARIO", "立即购买", [
                ("餐饮", .category), ("简约", .style), ("文艺青年", .audience), ("居家", .scene),
            ]),
        ]

        return items.enumerated().map { idx, item in
            return AdItem(
                id: "ec_\(idx)",
                title: item.title,
                description: item.desc,
                imageURL: "ec_image_\(idx)",
                videoURL: nil,
                cardType: [.bigImage, .smallImage].randomElement()!,
                channel: .ecommerce,
                tags: item.tags.map { AITag(id: "ec_tag_\(idx)_\($0.0)", name: $0.0, category: $0.1) },
                aiSummary: nil,
                sponsor: item.sponsor,
                ctaText: item.cta
            )
        }
    }

    private static func generateLocalAds() -> [AdItem] {
        let items: [(title: String, desc: String, cardType: AdCardType, sponsor: String, cta: String, tags: [(String, TagCategory)])] = [
            ("海底捞 欢聚四人套餐 限时优惠", "精选肥牛+招牌虾滑+脆毛肚+时蔬拼盘，赠送番茄牛腩锅底。到店免费美甲、水果畅吃。", .video, "海底捞", "预约餐位", [
                ("餐饮", .category), ("社交", .style), ("聚会达人", .audience), ("聚会", .scene),
            ]),
            ("SKP SELECT 年中大促", "国际大牌美妆护肤限时折扣，全场低至3折。消费满3000返300，VIP享双倍积分。", .video, "SKP", "查看商场", [
                ("服饰", .category), ("时尚", .style), ("都市丽人", .audience), ("购物", .scene),
            ]),
            ("Peloton 智能动感单车 体验店", "专业教练在线实时指导，阻力自动跟随课程调节。来店免费体验30分钟，满意再入手。", .video, "Peloton", "预约体验", [
                ("运动", .category), ("科技", .style), ("运动爱好者", .audience), ("健身", .scene),
            ]),
            ("奈雪的茶 霸气芝士芒果Pro", "新鲜台芒现切现做，厚芝士奶盖+脆波波。新品尝鲜8折，限时供应。", .video, "奈雪的茶", "新品尝鲜", [
                ("餐饮", .category), ("时尚", .style), ("学生党", .audience), ("聚会", .scene),
            ]),
            ("全家便利店 周三会员日", "每周三全场便当/饭团/沙拉第二件半价，冷饮买一赠一。新品冰面包限时尝鲜价。", .video, "全家 FamilyMart", "查看门店", [
                ("餐饮", .category), ("简约", .style), ("上班族", .audience), ("通勤", .scene),
            ]),
            ("Keepland 智能健身空间 新店开业", "按次付费无年卡捆绑，智能手环实时监测心率消耗。首节体验课免费，新人享专属折扣。", .video, "Keepland", "免费体验", [
                ("运动", .category), ("科技", .style), ("运动爱好者", .audience), ("健身", .scene),
            ]),
            ("蔚来中心 NIO House 试驾活动", "周末试驾ET7/ES6即赠NIO Life精品好礼。现场体验NIO Pilot全场景智能驾驶。", .video, "NIO 蔚来", "预约试驾", [
                ("汽车", .category), ("科技", .style), ("科技爱好者", .audience), ("周末出行", .scene),
            ]),
            ("盒马鲜生 海鲜现捞现做", "鲜活波龙/帝王蟹现捞现做，大厨现场烹饪。到店消费满200减30，会员享专属海鲜加工。", .video, "盒马鲜生", "到店消费", [
                ("餐饮", .category), ("社交", .style), ("家庭食客", .audience), ("周末出行", .scene),
            ]),
            ("环球影城 夏日限定夜场票", "哈利波特城堡夜间灯光秀，变形金刚3D对决全新升级。夜场票仅需199元起。", .video, "北京环球影城", "立即购票", [
                ("娱乐", .category), ("社交", .style), ("学生党", .audience), ("周末出行", .scene),
            ]),
            ("乐刻运动 私教体验课", "1v1专业教练定制训练计划，体态评估+营养建议。新会员首月仅需99元，无隐形消费。", .video, "乐刻运动", "免费体验", [
                ("运动", .category), ("简约", .style), ("运动爱好者", .audience), ("健身", .scene),
            ]),
            ("悦刻 电子雾化体验店", "来店免费体验多款口味，专业导购一对一讲解。新用户注册即享首单减免优惠。", .video, "悦刻 RELX", "到店试用", [
                ("零售", .category), ("科技", .style), ("潮流玩家", .audience), ("社交", .scene),
            ]),
            ("西西弗书店 读书分享会", "每周六下午作家见面会+新书签售。矢量咖啡买一赠一，阅读与咖啡的完美午后。", .video, "西西弗书店", "报名参与", [
                ("文化", .category), ("文艺", .style), ("文艺青年", .audience), ("周末出行", .scene),
            ]),
        ]

        return items.enumerated().map { idx, item in
            return AdItem(
                id: "local_\(idx)",
                title: item.title,
                description: item.desc,
                imageURL: "local_image_\(idx)",
                videoURL: "https://example.com/video/local_\(idx).mp4",
                cardType: AdCardType.allCases.randomElement()!,
                channel: .local,
                tags: item.tags.map { AITag(id: "local_tag_\(idx)_\($0.0)", name: $0.0, category: $0.1) },
                aiSummary: nil,
                sponsor: item.sponsor,
                ctaText: item.cta
            )
        }
    }
}
