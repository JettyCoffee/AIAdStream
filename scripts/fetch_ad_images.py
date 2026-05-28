#!/usr/bin/env python3
"""
从 Pexels API 爬取 300 张广告图片，生成 SQLite 种子数据库。
输出：AIAdStream/Resources/seed_ads.sqlite，包含 ad_items 和 ad_tags 两张表。
"""

import json
import time
import urllib.request
import urllib.parse
import ssl
import sqlite3
import os
API_KEY = "vIl2Ywc17zgKun3PLecxsVwhwDmYEPNMc2V9WOx49dVdMVAlDHsyveP2"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "AIAdStream", "Resources")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "seed_ads.sqlite")

# ── 广告内容池 ──────────────────────────────────────────────
# 每个概念生成 4 条广告变体，75 个概念 × 4 = 300 条广告
# 频道分布：featured 100 / ecommerce 100 / local 100

AD_CONCEPTS = [
    # ═══════════ Featured 频道 (25 概念 → 100 条) ═══════════
    # 科技数码
    ("featured", "wireless earbuds product", "headphones technology",
     ["真无线降噪耳机 Pro", "沉浸式空间音频耳机", "超长续航蓝牙耳机", "高清通话无线耳机"],
     ["自适应降噪，Hi-Res认证音质，40小时超长续航", "空间音频头部追踪，IPX5防水，运动无忧", "单次续航12小时，充电仓可充4次", "AI通话降噪，游戏低延迟模式"],
     ["SoundCore", "EchoBuds", "AudioTech", "PurePods"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("数码", "category"), ("科技", "style"), ("音乐爱好者", "audience"), ("通勤", "scene")]),

    ("featured", "smartphone technology", "mobile phone display",
     ["旗舰折叠屏手机", "AI影像旗舰手机", "轻薄性能手机", "游戏电竞手机"],
     ["折叠大屏+副屏双显示，UTG玻璃内折设计", "一英寸大底主摄，AI消除路人，夜拍神器", "7.2mm超薄机身，旗舰芯片，4500mAh大电池", "144Hz高刷屏，液冷散热3.0，肩键设计"],
     ["TechPeak", "NovaMobile", "OneCore", "PhantomX"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("数码", "category"), ("科技", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("featured", "mirrorless camera professional", "dslr camera lens",
     ["全画幅微单相机 A7R6", "APS-C画幅微单", "旁轴复古数码相机", "Vlog运动相机"],
     ["6100万像素，8级防抖，AI智能追焦", "轻便旅拍神器，4K/60p无裁切", "经典旁轴设计，胶片模拟色彩", "5.3K/60fps，HorizonLock水平锁定"],
     ["Sony", "FujiFilm", "LeicaTech", "GoAction"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("数码", "category"), ("科技", "style"), ("摄影爱好者", "audience"), ("旅行", "scene")]),

    ("featured", "smartwatch fitness", "wearable device technology",
     ["智能手表 Ultra 2", "GT Runner 运动手表", "儿童智能手表", "时尚智能腕表"],
     ["蓝宝石玻璃+钛合金表壳，血氧+ECG心电图", "双频五星定位，马拉松级续航21天", "GPS定位，视频通话，安全守护", "AMOLED圆形表盘，百变表盘市场"],
     ["AppleWatch", "GTWatch", "SafeKids", "ChicTime"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("数码", "category"), ("科技", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("featured", "laptop computer desk", "macbook workspace",
     ["AI轻薄笔记本 Pro 16", "创作本 Studio 15", "二合一触控笔记本", "商用办公笔记本"],
     ["M4芯片，18小时续航，Liquid Retina XDR屏", "RTX 5070+4K OLED，创意工作者的移动工作站", "360翻转触控屏，手写笔支持", "指纹+面部识别，军工级耐用，3年上门保修"],
     ["TechBook", "CreatorPC", "FlexTab", "BizNote"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("数码", "category"), ("科技", "style"), ("上班族", "audience"), ("居家", "scene")]),

    # 运动户外
    ("featured", "running shoes nike adidas", "sneakers athletic footwear",
     ["碳板竞速跑鞋", "城市慢跑鞋", "越野登山鞋", "综训健身鞋"],
     ["全掌碳板+ZoomX中底，推进力提升15%", "加厚缓震中底，适合日常5-10公里", "Vibram大底+Gore-Tex防水，全地形通过", "多向支撑+耐磨橡胶，HIIT/跳绳/深蹲适用"],
     ["Nike", "RunCloud", "TrailPro", "FlexFit"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("运动", "category"), ("科技", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("featured", "yoga fitness woman", "yoga mat workout",
     ["Align 高腰运动紧身裤", "无缝针织运动背心", "天然橡胶瑜伽垫 Pro", "智能计数跳绳"],
     ["Nulu面料奶油般柔软，四面弹力，吸汗速干", "一体针织工艺，无侧缝不摩擦，高度支撑", "5mm天然橡胶+PU表层，防滑干湿两用", "霍尔传感器计数，APP蓝牙同步运动数据"],
     ["lululemon", "AuraActive", "MandukaX", "JumpSmart"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("运动", "category"), ("时尚", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("featured", "camping outdoor tent", "hiking backpack adventure",
     ["轻量双人帐篷 Cloud 2", "户外冲锋衣三合一", "折叠露营椅", "钛合金户外炊具"],
     ["15D尼龙面料，重量仅1.2kg，3季通用", "Gore-Tex Pro防水+800蓬鹅绒内胆", "7075铝合金骨架，承重150kg", "钛合金锅具4件套，总重仅350g"],
     ["NatureHike", "ArcTeryX", "Helinox", "SnowPeak"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("运动", "category"), ("简约", "style"), ("户外爱好者", "audience"), ("户外", "scene")]),

    # 美妆护肤
    ("featured", "skincare product beauty", "facial serum luxury skincare",
     ["神仙水 护肤精华露", "视黄醇抗皱精华", "维C亮肤精华液", "玻尿酸补水精华"],
     ["90%天然活酵母精萃Pitera，改善肌肤五大维度", "0.3%包裹视黄醇+神经酰胺，温和抗老", "15%左旋维C+阿魏酸，提亮抗氧化", "三重分子量玻尿酸，层层渗透补水"],
     ["SK-II", "EsteeLauder", "VitaminGlow", "Hyaluronic+"],
     ["限时优惠", "了解详情", "立即选购", "加入购物车"],
     [("美妆", "category"), ("简约", "style"), ("都市丽人", "audience"), ("居家", "scene")]),

    ("featured", "perfume fragrance luxury", "cosmetics makeup product",
     ["经典5号香水", "东方沉香淡香精", "花园系列淡香水", "限定联名香氛礼盒"],
     ["格拉斯茉莉+五月玫瑰，经典醛香调", "老挝沉香+土耳其玫瑰，神秘东方调", "普罗旺斯薰衣草+地中海柑橘", "艺术家联名瓶身设计，花果香调"],
     ["Chanel", "TomFord", "JoMalone", "Diptyque"],
     ["了解详情", "限时优惠", "立即选购", "加入购物车"],
     [("美妆", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("送礼", "scene")]),

    ("featured", "hair styling tool dyson", "hair dryer professional",
     ["吹风直发器 AirStrait", "高速负离子吹风机", "自动卷发棒", "直发梳造型器"],
     ["气流直发技术，无需极热减少62%热损伤", "11万转/分高速马达，2亿负离子护发", "凯夫拉材质，自动识别发量调节温度", "陶瓷涂层发热，恒温185°C防烫设计"],
     ["Dyson", "AirFly", "CurlBot", "StylePro"],
     ["限时优惠", "立即选购", "了解详情", "加入购物车"],
     [("美妆", "category"), ("科技", "style"), ("都市丽人", "audience"), ("居家", "scene")]),

    # 服饰时尚
    ("featured", "luxury watch men", "wristwatch fashion accessory",
     ["经典机械腕表", "飞行员计时腕表", "潜水运动腕表", "智能混合腕表"],
     ["自产机芯Cal.324，18K金摆陀，日内瓦印记", "陶瓷表圈+钛合金表壳，72小时动储", "300米防水+排氦阀，陶瓷表圈单向旋转", "经典指针+隐藏式智能屏幕，14天续航"],
     ["PatekPhilipe", "IWC", "OmegaMarine", "HybridTime"],
     ["了解详情", "限时优惠", "立即选购", "加入购物车"],
     [("服饰", "category"), ("经典", "style"), ("商务人士", "audience"), ("送礼", "scene")]),

    ("featured", "designer handbag fashion", "luxury bag leather accessory",
     ["经典翻盖包 2.55", "托特通勤包", "斜挎马鞍包", "迷你水桶包"],
     ["小羊皮+菱形绗缝+双C扣，经典永不过时", "荔枝纹牛皮，可装14寸笔记本，通勤首选", "意大利植鞣牛皮+黄铜五金，复古做旧", "抽绳束口+可拆卸肩带，一包两用"],
     ["Chanel", "Longchamp", "SaddleLeather", "MiniBucket"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("服饰", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("通勤", "scene")]),

    ("featured", "sunglasses eyewear fashion", "optical glasses design",
     ["飞行员太阳镜 Classic", "折叠墨镜 UltraSlim", "蓝光防疲劳眼镜", "变色运动太阳镜"],
     ["偏光镜片+金属框架，UV400防护", "5mm超薄折叠设计，仅重18g", "蔡司防蓝光镜片，适合长时间办公", "光致变色技术，透明↔深灰自适应"],
     ["RayBan", "ROAV", "ZeissCare", "Oakley"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("服饰", "category"), ("时尚", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    # 汽车出行
    ("featured", "electric car technology", "luxury automobile vehicle",
     ["智能电动旗舰轿车 ET9", "全场景智能SUV ES7", "纯电轿跑 GT70", "城市通勤电动车"],
     ["全域900V架构，续航1000km，零重力座椅", "双电机四驱，3.8秒破百，NOP+全域领航", "蝴蝶门设计，2.1秒破百，赛道模式", "5门4座，300km续航，L2级智驾辅助"],
     ["NIO 蔚来", "LiAuto", "XPeng", "BYD"],
     ["预约试驾", "了解详情", "限时优惠", "立即选购"],
     [("汽车", "category"), ("科技", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("featured", "bicycle cycling sport", "electric scooter transportation",
     ["碳纤维公路车 SL8", "折叠电动滑板车", "城市通勤自行车", "智能电动自行车"],
     ["T1100碳纤维车架，Shimano Ultegra套件", "500W电机，35km续航，3秒快速折叠", "内变速8速+皮带传动，免维护设计", "力矩传感器，5档助力，续航100km"],
     ["Specialized", "Segway", "CityBike", "Xiaomi"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("运动", "category"), ("科技", "style"), ("户外爱好者", "audience"), ("通勤", "scene")]),

    # 家居生活
    ("featured", "robot vacuum cleaner", "smart home appliance",
     ["扫拖一体机器人 X30", "无线洗地机 3.0", "智能空气净化器", "全自动擦窗机器人"],
     ["8000Pa吸力，热水洗拖布，AI避障", "滚刷自清洁+热风烘干，一推即净", "HEPA H13滤网+UV杀菌，CADR 500", "真空吸附+边框识别，干湿双擦"],
     ["Roborock", "Dyson", "Xiaomi", "CleanBot"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("家电", "category"), ("科技", "style"), ("宝妈", "audience"), ("居家", "scene")]),

    ("featured", "coffee maker machine", "espresso machine kitchen",
     ["意式半自动咖啡机", "全自动咖啡机 LatteGo", "胶囊咖啡机 Mini", "手冲咖啡套装 Pro"],
     ["15bar压力+PID温控，专业萃取", "一键出拿铁，奶泡绵密可调", "30秒预热，20bar高压萃取，小巧机身", "温控手冲壶+电子秤+双层玻璃滤杯"],
     ["Breville", "Philips", "Nespresso", "Brewista"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("餐饮", "category"), ("简约", "style"), ("文艺青年", "audience"), ("居家", "scene")]),

    ("featured", "modern furniture design", "interior design minimal living room",
     ["模块化沙发 Cloud", "电动升降桌 Pro", "人体工学椅 Ergo", "氛围落地灯"],
     ["自由组合，科技布面料防猫抓防泼溅", "双电机驱动，记忆高度，65-130cm升降", "4D扶手+腰靠调节，韩国Wintex网布", "3000K-6000K色温无极调光，RA≥95"],
     ["IKEA", "FlexiSpot", "HermanMiller", "PhilipsHue"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("家居", "category"), ("简约", "style"), ("上班族", "audience"), ("居家", "scene")]),

    # 美食
    ("featured", "chocolate dessert luxury", "pastry cake bakery",
     ["手工松露巧克力礼盒", "经典提拉米苏蛋糕", "法式马卡龙礼盒 12枚", "日式抹茶生巧克力"],
     ["比利时进口可可豆，72%可可含量", "马斯卡彭芝士+手指饼干+现磨咖啡", "玫瑰/开心果/海盐焦糖/柠檬4种口味", "宇治抹茶+白巧克力，入口即化"],
     ["Godiva", "TiramisuClassic", "Ladurée", "Royce"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("食品", "category"), ("时尚", "style"), ("聚会达人", "audience"), ("送礼", "scene")]),

    ("featured", "wine glass bottle luxury", "whiskey liquor premium alcohol",
     ["单一麦芽威士忌 18年", "波尔多列级庄红酒", "精酿IPA啤酒套装", "山崎 12年 单一麦芽"],
     ["雪莉桶陈酿18年，干果+黑巧克力风味", "赤霞珠+梅洛混酿，橡木桶陈酿18个月", "6款IPA+世涛组合，330ml×12瓶", "水楢橡木桶收尾，东方禅意风味"],
     ["Macallan", "Lafite", ["BrewDog"], "Yamazaki"],
     ["了解详情", "立即选购", "限时优惠", "加入购物车"],
     [("食品", "category"), ("经典", "style"), ("商务人士", "audience"), ("送礼", "scene")]),

    ("featured", "sushi japanese food", "steak restaurant fine dining",
     ["Omakase 主厨发办", "干式熟成牛排套餐", "黑松露意面", "和牛寿喜烧"],
     ["当日空运渔获，12贯季节手握寿司", "45天干式熟成肋眼，配烤骨髓+红酒汁", "新鲜黑松露现刨+帕玛森奶酪轮", "A5和牛+无菌蛋液，关西风寿喜烧"],
     ["SushiSaito", "Wolfgang", "Tartufo", "Moritaya"],
     ["预约餐位", "了解详情", "立即选购", "加入购物车"],
     [("餐饮", "category"), ("时尚", "style"), ("聚会达人", "audience"), ("聚会", "scene")]),

    # 旅行
    ("featured", "travel destination beach", "luxury resort hotel pool",
     ["马尔代夫水上别墅", "京都町家旅馆", "北欧极光玻璃屋", "圣托里尼洞穴酒店"],
     ["私人泳池+玻璃地板+24小时管家服务", "百年町家改建，枯山水庭院+茶道体验", "全景玻璃屋顶，躺在床上看极光", "悬崖洞穴改建，爱琴海日落无边泳池"],
     ["FourSeasons", "AmanKyoto", "ArcticResort", "CavoTagoo"],
     ["探索更多", "了解详情", "立即预订", "加入收藏"],
     [("旅行", "category"), ("文艺", "style"), ("旅行爱好者", "audience"), ("旅行", "scene")]),

    # 母婴
    ("featured", "baby products toys", "children toy educational",
     ["智能婴儿监护器", "儿童编程机器人", "折叠婴儿推车", "有机棉婴儿礼盒"],
     ["4K夜视+AI哭闹检测+呼吸监测", "无屏编程，积木式指令，5-12岁适用", "一键折叠，可登机，仅重6.6kg", "GOTS认证有机棉，6件套新生儿礼盒"],
     ["Owlet", ["Makeblock"], "Bugaboo", "aden+anais"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("母婴", "category"), ("科技", "style"), ("宝妈", "audience"), ("居家", "scene")]),

    # 宠物
    ("featured", "pet dog accessories product", "cat pet supplies",
     ["智能自动喂食器", "宠物GPS定位项圈", "猫砂盆机器人", "宠物推车背包"],
     ["APP远程出粮，6L大容量，双电源供电", "实时定位+电子围栏+运动监测", "自动铲屎+除臭，APP健康监测", "可折叠宠物推车+透气背包二合一"],
     ["PetKit", ["Tractive"], "LitterRobot", "AirBuggy"],
     ["立即选购", "了解详情", "限时优惠", "加入购物车"],
     [("宠物", "category"), ("科技", "style"), ("铲屎官", "audience"), ("居家", "scene")]),

    # ═══════════ Ecommerce 频道 (25 概念 → 100 条) ═══════════
    ("ecommerce", "skincare serum beauty product", "facial skincare luxury",
     ["双抗精华液 30ml", "神经酰胺面霜", "果酸焕肤精华", "熬夜急救面膜"],
     ["虾青素+VC双抗体系，抗糖+抗氧化双通路", "三重神经酰胺+胆固醇+脂肪酸，修复屏障", "6%杏仁酸+水杨酸，温和去闭口黑头", "烟酰胺+透明质酸，15分钟急速提亮"],
     ["珀莱雅", "Cerave", "PaulaChoice", "Filorga"],
     ["限时秒杀", "领券购买", "加入购物车", "立即下单"],
     [("美妆", "category"), ("简约", "style"), ("都市丽人", "audience"), ("居家", "scene")]),

    ("ecommerce", "snack food nuts chips", "healthy snack dried fruit",
     ["每日坚果混合装 750g", "冻干草莓巧克力", "低脂高蛋白零食盒", "进口威化饼干礼盒"],
     ["6种坚果+4种果干，独立锁鲜小包装", "整颗草莓冻干+比利时白巧克力涂层", "鸡胸肉干+鹰嘴豆脆+蛋白棒组合装", "5层酥脆+榛子夹心，奥地利进口"],
     ["三只松鼠", "可可派", "KeepFit", "Loacker"],
     ["立即抢购", "领券购买", "加入购物车", "限时秒杀"],
     [("食品", "category"), ("简约", "style"), ("学生党", "audience"), ("居家", "scene")]),

    ("ecommerce", "phone charger usb cable", "gan charger power adapter",
     ["GaN 氮化镓充电器 100W", "MagSafe三合一充电站", "移动电源 20000mAh", "桌面充电站 6口"],
     ["3口快充，PD3.1+PPS协议，30分钟充80%", "磁吸充电iPhone+Watch+AirPods同时充", "65W双向快充，数显屏幕，可登机", "6口USB+2AC，200W总功率，桌面理线"],
     ["Anker 安克", "Apple", "Xiaomi", "Baseus"],
     ["领券购买", "限时秒杀", "加入购物车", "立即下单"],
     [("数码", "category"), ("科技", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("ecommerce", "kitchen appliance air fryer", "cooking kitchen gadget",
     ["智能空气炸锅 5.5L", "破壁料理机 Pro", "多功能电煮锅", "真空低温料理机"],
     ["360°热风循环，100+云食谱，OLED触控", ["1200W大功率，8叶刀头，24小时预约"], "2L容量，蒸煮焖炖涮一锅搞定", "精准控温±0.5°C，APP远程控制"],
     ["Xiaomi 小米", "Joyoung 九阳", "MorphyRichards", "Anova"],
     ["立即下单", "领券购买", "加入购物车", "限时秒杀"],
     [("家电", "category"), ("简约", "style"), ("宝妈", "audience"), ("居家", "scene")]),

    ("ecommerce", "women dress fashion summer", "floral clothing fashion style",
     ["法式碎花连衣裙", "通勤西装外套", "高腰阔腿裤", "羊绒开衫毛衣"],
     ["轻盈雪纺面料，V领收腰设计，多色可选", "TR弹力面料，收腰显瘦，干洗可机洗", "垂坠感面料，高腰设计，拉长腿部比例", "100%山羊绒，12针细密织法，亲肤保暖"],
     ["ZARA", "Theory", "Uniqlo", "Erdos"],
     ["查看尺码", "加入购物车", "限时秒杀", "领券购买"],
     [("服装", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("聚会", "scene")]),

    ("ecommerce", "backpack bag travel", "luggage suitcase travel gear",
     ["轻量双肩包 16L", ["前开口登机箱 20寸"], "商务旅行背包", "相机内胆双肩包"],
     ["X-Pac防水面料，YKK拉链，仅重480g", "PC+ABS材质，TSA海关锁，360°万向轮", "可装17寸笔记本+2天差旅衣物", "DIY魔术贴隔板，侧开快取相机仓"],
     ["Bellroy", "Rimowa", "TumiTech", "PeakDesign"],
     ["加入购物车", "领券购买", "立即下单", "限时秒杀"],
     [("服饰", "category"), ("简约", "style"), ("商务人士", "audience"), ("旅行", "scene")]),

    ("ecommerce", "eyeshadow makeup palette", "lipstick cosmetics beauty",
     ["12色动物眼影盘", "哑光丝绒唇釉", "持久不脱妆粉底液", "三色修容盘"],
     ["小鹿盘圣诞限定，细腻显色不易飞粉", "空气感质地，不沾杯不显唇纹", "24小时持妆，遮瑕自然不假面", "阴影+高光+腮红一盘搞定立体轮廓"],
     ["完美日记", "3CE", "EsteeLauder", "TooCoolForSchool"],
     ["加入购物车", "限时秒杀", "领券购买", "立即下单"],
     [("美妆", "category"), ("时尚", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("ecommerce", "aroma diffuser essential oil", "scented candle home fragrance",
     ["超声波香薰机 Mini", "大豆蜡香薰蜡烛", "车载香氛套装", "藤条无火香薰"],
     ["静音运行+4档定时+自动断电", "美国大豆蜡+植物精油，燃烧约60小时", "出风口夹+固体香膏，可持续90天", "意大利进口精油，天然挥发棒"],
     ["MUJI 无印良品", "JoMalone", "Diptyque", "CultiMilano"],
     ["立即选购", "加入购物车", "领券购买", "限时秒杀"],
     [("家居", "category"), ("简约", "style"), ("文艺青年", "audience"), ("居家", "scene")]),

    ("ecommerce", "tea set chinese traditional", "ceramic mug cup design",
     ["紫砂壶套装 6件套", "手工锤纹玻璃茶具", "钛合金旅行茶具", "建盏 油滴天目杯"],
     ["宜兴原矿紫砂，手工拍打成型", "高硼硅玻璃+304不锈钢滤网", "纯钛材质仅重280g，一壶两杯可收纳", "建阳水吉镇烧制，铁系结晶釉"],
     ["宜兴紫砂", "Bodum", "SnowPeak", "建盏非遗"],
     ["加入购物车", "限时秒杀", "立即下单", "领券购买"],
     [("家居", "category"), ("经典", "style"), ("文艺青年", "audience"), ("送礼", "scene")]),

    ("ecommerce", "desk lamp led", "table lamp design modern",
     ["屏幕挂灯 Pro", "护眼台灯 国AA级", "氛围床头灯", "便携补光灯"],
     ["非对称前向投光，无屏幕反光，RA≥95", "智能调光+入座感应，无频闪无蓝光危害", "2700K暖光+无极调光，月牙造型", "RGB全彩+9种光效，磁吸安装，Type-C充电"],
     ["BenQ", "Philips", "Muji", "Ulanzi"],
     ["加入购物车", "限时秒杀", "领券购买", "立即下单"],
     [("家电", "category"), ("科技", "style"), ("上班族", "audience"), ("居家", "scene")]),

    ("ecommerce", "gaming console nintendo", "video game controller playstation",
     ["Switch OLED 游戏机", "PS5 光驱版主机", "Steam Deck OLED", "精英无线手柄"],
     ["7英寸OLED屏+宽幅支架+白色Joy-Con", "DualSense手柄+825GB SSD+光线追踪", "7.4英寸HDR OLED+90Hz高刷+FPS帧率提升", "4背键+可拆卸摇杆+扳机行程锁"],
     ["Nintendo 任天堂", "Sony", "Valve", "Xbox"],
     ["立即购买", "加入购物车", "领券购买", "限时秒杀"],
     [("玩具", "category"), ("科技", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("ecommerce", "plant flower bouquet", "succulent plant pot indoor",
     ["每周鲜花订阅", "多肉植物盲盒", "永生花玻璃罩", "大型室内绿植 琴叶榕"],
     ["云南直发，每周随机花材，含花瓶+营养液", "随机6颗精品多肉+手作陶盆", "厄瓜多尔永生玫瑰，可保存3-5年", "1.5-1.8米高大植株，含自吸水盆+配送上门"],
     ["花点时间", "多肉说", "RoseOnly", "超级植物"],
     ["加入购物车", "限时秒杀", "立即下单", "领券购买"],
     [("家居", "category"), ("文艺", "style"), ("都市丽人", "audience"), ("送礼", "scene")]),

    ("ecommerce", "headphones bluetooth wireless", "earbuds noise cancelling",
     ["头戴降噪耳机 QC Ultra", "开放式运动耳机", "骨传导游泳耳机", "复古头戴式耳机"],
     ["空间音频，CustomTune智能音场调校", "不入耳设计，环境感知，运动安全", "IPX8防水，蓝牙+MP3双模，32G内存", "胡桃木腔体+头层牛皮头梁，HiFi音质"],
     ["Bose", "Shokz", "Naenka", "MezeAudio"],
     ["加入购物车", "领券购买", "立即下单", "限时秒杀"],
     [("数码", "category"), ("科技", "style"), ("音乐爱好者", "audience"), ("通勤", "scene")]),

    ("ecommerce", "vitamin supplement health", "protein powder fitness nutrition",
     ["复合维生素 每日一袋", "乳清蛋白粉 2.27kg", "益生菌胶囊 60粒", "Omega-3深海鱼油"],
     ["30种维生素矿物质，按日包装方便携带", "25g蛋白质/份，5.5g BCAA，巧克力味", "500亿CFU/粒，12种菌株联合", "EPA+DHA 1000mg，分子蒸馏纯化"],
     ["Swisse", "Optimum", "LifeSpace", "Blackmores"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("健康", "category"), ("简约", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("ecommerce", "toothbrush electric dental care", "electric toothbrush oral care",
     ["声波电动牙刷 Pro", "冲牙器 便携款", "牙齿美白套装", "儿童电动牙刷"],
     ["41000次/分声波震动，30秒分区提醒", "1400次/分高频脉冲，200ml水箱", "6%过氧化氢美白贴+LED蓝光加速器", "IPX7防水+趣味APP刷牙游戏+卡通造型"],
     ["飞利浦", "Waterpik", "Crest", "Babysonic"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("健康", "category"), ("科技", "style"), ("宝妈", "audience"), ("居家", "scene")]),

    ("ecommerce", "running shoes nike sneakers", "athletic sport shoes fashion",
     ["复古慢跑鞋 2002R", "飞织运动鞋", "小白鞋 经典款", "厚底增高鞋"],
     ["ABZORB中底+N-ERGY缓震，90年代跑鞋复刻", "一体飞织鞋面，袜套式包裹，赤足体验", "头层牛皮+橡胶大底，百搭不挑人", "6cm隐形增高，EVA轻量大底"],
     ["NewBalance", "Nike", "CommonProjects", "Skechers"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("运动", "category"), ("时尚", "style"), ("学生党", "audience"), ("通勤", "scene")]),

    ("ecommerce", "cooking pan kitchen", "stainless steel cookware kitchenware",
     ["不粘炒锅 32cm", "珐琅铸铁锅", "钛不粘煎锅", "厨房刀具套装"],
     ["瑞士ILAG涂层+铝合金锅体，无油烟", "24cm圆形，自循环水珠设计，焖炖神器", "纯钛+陶瓷不粘层，无涂层更健康", "5Cr15MoV不锈钢，6件套含刀架"],
     ["双立人", "LeCreuset", "Keiss", "十八子作"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("家居", "category"), ("经典", "style"), ("家庭食客", "audience"), ("居家", "scene")]),

    ("ecommerce", "office chair ergonomic", "standing desk adjustable",
     ["双电机升降桌 140cm", ["网面人体工学椅"], "显示器支架", "桌下理线收纳架"],
     ["双电机驱动，记忆高度4档，遇阻回退", "韩国Wintex网布+4D扶手+自适应腰靠", "气压弹簧+USB 3.0 Hub，承重9kg", "免钉卡扣安装，可收纳插排+线缆"],
     ["FlexiSpot", "Humanscale", "Ergotron", "IKEA"],
     ["加入购物车", "立即下单", "限时秒杀", "领券购买"],
     [("家居", "category"), ("科技", "style"), ("上班族", "audience"), ("居家", "scene")]),

    ("ecommerce", "lego building blocks toy", "model car kit collectible",
     ["科技系列 法拉利 Daytona SP3", "ideas系列 打字机", "机械组 兰博基尼Countach", "花束系列 玫瑰"],
     ["1:8比例，3778颗粒，可动引擎+变速箱", "还原经典机械打字机结构，2078颗粒", "可动剪刀门+尾翼，1506颗粒", "永生花创意拼搭，可做家居装饰"],
     ["LEGO 乐高", "LEGO", "LEGO", "LEGO"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("玩具", "category"), ("复古", "style"), ("家庭食客", "audience"), ("居家", "scene")]),

    ("ecommerce", "water bottle insulated", "tumbler water bottle travel mug",
     ["真空保温杯 500ml", "智能水杯", "运动水壶 750ml", "钛合金茶杯"],
     ["316不锈钢+真空双层，保冷24h/保温12h", "OLED屏显示温度+饮水量+提醒", "Tritan材质+锁扣防漏+可装碳酸饮料", "纯钛材质仅重180g，一壶一杯可叠放"],
     ["膳魔师", "Hidrate", "CamelBak", "SnowPeak"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("运动", "category"), ("简约", "style"), ("户外爱好者", "audience"), ("户外", "scene")]),

    ("ecommerce", "facial mask sheet skincare", "sheet mask beauty korean",
     ["胶原蛋白面膜 5片装", "炭黑清洁面膜", "睡眠免洗面膜", "黄金眼膜 60片"],
     ["水解胶原蛋白+B5，15分钟急救补水", "竹炭纤维膜布+茶树精油，吸附黑头", "积雪草+神经酰胺，夜间修复屏障", "24K纳米金+烟酰胺，淡化细纹"],
     ["敷尔佳", "Innisfree", "Laneige", "JM Solution"],
     ["限时秒杀", "加入购物车", "领券购买", "立即下单"],
     [("美妆", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("居家", "scene")]),

    ("ecommerce", "mechanical keyboard custom", "gaming mouse computer peripheral",
     ["客制化机械键盘 75%", "三模无线鼠标", "铝合金掌托", "RGB鼠标垫"],
     ["Gasket结构+PC定位板+热插拔轴座", "PAW3395传感器+4K接收器+55g轻量", "6063铝合金+阳极氧化，完美匹配75%键盘", "15W无线充电+15种灯光模式"],
     ["keychron", "Logitech", "Wooting", "Razer"],
     ["加入购物车", "限时秒杀", "领券购买", "立即下单"],
     [("数码", "category"), ("科技", "style"), ("科技爱好者", "audience"), ("居家", "scene")]),

    ("ecommerce", "t shirt cotton clothing", "basic tshirt casual wear fashion",
     ["重磅纯棉T恤 300g", "亚麻衬衫 长袖", "美利奴羊毛打底衫", "速干POLO衫"],
     ["新疆长绒棉+双面磨毛，不透不皱", "法国诺曼底亚麻，越洗越软", "17.5微米超细美利奴，亲肤可贴身穿", "CoolMax面料+UPF50+，商务休闲两穿"],
     ["白小T", "J.Crew", "Icebreaker", "RalphLauren"],
     ["加入购物车", "查看尺码", "限时秒杀", "领券购买"],
     [("服装", "category"), ("简约", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("ecommerce", "face serum vitamin c", "retinol cream skincare anti aging",
     ["视黄醇精华 0.5%", "玻尿酸B5精华", "烟酰胺控油精华", "多肽抗皱精华"],
     ["包裹缓释技术，温和不刺激，搭配烟酰胺", "4D透明质酸+B5泛醇，深层补水修复", "10%烟酰胺+1%锌，控油收毛孔", "Matrixyl 3000+Argireline，淡纹提升"],
     ["露得清", "修丽可", "The Ordinary", "Olay"],
     ["加入购物车", "限时秒杀", "领券购买", "立即下单"],
     [("美妆", "category"), ("科技", "style"), ("都市丽人", "audience"), ("居家", "scene")]),

    ("ecommerce", "coffee beans bag packaging", "pour over coffee drip equipment",
     ["单一产地咖啡豆 200g", "挂耳咖啡 30包装", ["冷萃咖啡液 12条"], "精品速溶咖啡"],
     ["埃塞俄比亚耶加雪菲，水洗处理，浅烘", "6种风味混合装，独立充氮锁鲜", "哥伦比亚+危地马拉拼配，10倍浓缩液", "冻干技术，3秒即溶，冷热水均可"],
     ["瑞幸", "三顿半", "永璞", "隅田川"],
     ["加入购物车", "领券购买", "限时秒杀", "立即下单"],
     [("餐饮", "category"), ("简约", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    # ═══════════ Local 频道 (25 概念 → 100 条) ═══════════
    ("local", "hotpot restaurant chinese", "restaurant interior dining",
     ["欢聚火锅四人套餐", "潮汕牛肉火锅 双人餐", "重庆老火锅 不限量", "日式涮涮锅 放题"],
     ["精选肥牛+虾滑+脆毛肚+时蔬拼盘", "当日现切吊龙+匙柄+胸口油+手打牛丸", "九宫格红汤锅底+100+种菜品畅吃", "黑毛和牛+松叶蟹放题，90分钟畅吃"],
     ["海底捞", "八合里", "珮姐", "温野菜"],
     ["预约餐位", "查看菜单", "排队取号", "限时优惠"],
     [("餐饮", "category"), ("社交", "style"), ("聚会达人", "audience"), ("聚会", "scene")]),

    ("local", "shopping mall luxury retail", "department store fashion retail",
     ["年中大促 美妆节", "国际名品限时折扣", "新店开业 VIP专场", "会员日 积分翻倍"],
     ["全场美妆低至3折+满3000返300", "Gucci/Burberry/Prada限时7折起", "首单8折+赠品牌小样三件套", "30万积分可兑戴森吹风机"],
     ["SKP", "万象城", "太古里", "IFS"],
     ["查看商场", "领取优惠", "报名参与", "预约专车"],
     [("购物", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("购物", "scene")]),

    ("local", "gym fitness interior workout", "fitness studio exercise equipment",
     ["智能健身空间 私教课", "CrossFit 体验课", "瑜伽小班课 月卡", "单车派对 45分钟"],
     ["按次付费无年卡+智能手环实时监测", "基础动作教学+WOD训练，零基础可参加", "哈他/阴/流/阿斯汤加，小班8人", "夜店灯光+DJ打碟+教练带节奏骑行"],
     ["Keepland", "CrossFit", "PureYoga", "SpaceCycle"],
     ["免费体验", "预约课程", "立即报名", "了解详情"],
     [("运动", "category"), ("科技", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("local", "bubble tea drink shop", "milk tea beverage boba tea",
     ["霸气芝士芒果 Pro", "黑糖珍珠鲜奶", "多肉葡萄 限定款", "杨枝甘露 经典款"],
     ["新鲜台芒现切+厚芝士奶盖+脆波波", "手炒黑糖挂壁+明治鲜奶+软糯珍珠", "手剥巨峰葡萄+绿妍茶底+脆波波", "泰国金枕头榴莲+西柚粒+椰浆"],
     ["奈雪的茶", "喜茶", "古茗", "七分甜"],
     ["新品尝鲜", "立即下单", "限时优惠", "加入购物车"],
     [("餐饮", "category"), ("时尚", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("local", "coffee shop cafe interior", "coffee latte art barista",
     ["SOE拿铁 限定豆", "冷萃咖啡 夏日特调", "手冲咖啡 品鉴套餐", "精品可可 热巧克力"],
     ["埃塞俄比亚古吉日晒，水蜜桃+红茶尾韵", "12小时冷萃+柚子+迷迭香创意特调", ["3款单一产地咖啡豆对比品鉴"], "法芙娜70%黑巧+鲜牛乳+海盐奶盖"],
     ["瑞幸", "M Stand", "Seesaw", "阿拉比卡"],
     ["立即下单", "查看门店", "限时优惠", "加入购物车"],
     [("餐饮", "category"), ("文艺", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("local", "convenience store interior retail", "supermarket grocery fresh food",
     ["周三会员日 全场折扣", "生鲜到家 最快30分钟", "熟食便当日 第二件半价", "便利店自制饮品节"],
     ["便当/饭团/沙拉满30减10", "活虾活蟹现捞+蔬菜水果冷链配送", "红烧牛肉饭/照烧鸡腿饭/寿司拼盘", "现磨咖啡+冰沙+奶茶全系列8折"],
     ["全家 FamilyMart", "盒马鲜生", "7-Eleven", "便利蜂"],
     ["查看门店", "立即下单", "加入购物车", "限时优惠"],
     [("餐饮", "category"), ("简约", "style"), ("上班族", "audience"), ("通勤", "scene")]),

    ("local", "movie theater cinema screen", "imax cinema movie theater entertainment",
     ["IMAX 激光厅 新片上映", "杜比影院 沉浸体验", "VIP贵宾厅 双人套票", "4D动感影厅 亲子观影"],
     ["科幻大片首选 IMAX 激光4K+12.1声道", "杜比视界+杜比全景声，100万:1对比度", "真皮电动沙发+呼叫服务+免费小食", "座椅运动+风/雨/气味特效+亲子动画"],
     ["万达影城", "CGV影城", "百丽宫", ["中影国际"]],
     ["立即购票", "查看排片", "了解详情", "加入购物车"],
     [("娱乐", "category"), ("社交", "style"), ("聚会达人", "audience"), ("周末出行", "scene")]),

    ("local", "amusement park theme park", "roller coaster theme park",
     ["夏日限定夜场票", "双人全日票+酒店", "儿童乐园 年卡", "水上乐园 畅玩季票"],
     ["夜场灯光秀+城堡烟花+游乐项目", "主题酒店1晚+双人入园+快速通行证", "室内+户外50+项目，全年不限次", "造浪池+漂流河+15条滑道+亲子区"],
     ["北京环球影城", "迪士尼乐园", "奈尔宝", "长隆水上乐园"],
     ["立即购票", "查看套餐", "了解详情", "限时优惠"],
     [("娱乐", "category"), ("社交", "style"), ("学生党", "audience"), ("周末出行", "scene")]),

    ("local", "spa massage wellness", "massage spa beauty treatment",
     ["精油SPA 全身放松 60min", "泰式古法按摩 90min", "足疗+采耳 双人套餐", "面部皮肤管理 韩国进口"],
     ["薰衣草+甜杏仁油，瑞典式放松手法", "被动瑜伽拉伸+穴位按压", "中药泡脚+肩颈放松+专业采耳", ["Aqua Peel小气泡+LED光疗+补水面膜"]],
     ["康骏", "泰合玺", "华夏良子", "悦诗风吟SPA"],
     ["预约体验", "立即预约", "了解详情", "限时优惠"],
     [("健康", "category"), ("简约", "style"), ("上班族", "audience"), ("周末出行", "scene")]),

    ("local", "bookstore reading coffee shop", "library bookshelf reading space",
     ["读书分享会 每周六", "新书签售会 限量", "儿童绘本阅读角", "书店+咖啡 会员日"],
     ["作家见面+新书分享+读者交流", ["人气作家空降+签名售书+限定周边"], "每周日绘本故事会+手工DIY", "矢量咖啡买一赠一+全场图书8折"],
     ["西西弗书店", "钟书阁", "PageOne", "诚品书店"],
     ["报名参与", "立即预约", "了解详情", "加入购物车"],
     [("文化", "category"), ("文艺", "style"), ("文艺青年", "audience"), ("周末出行", "scene")]),

    ("local", "flower shop bouquet store", "florist flower arrangement plant",
     ["花艺手作课 周末班", "定制花束 当日达", "绿植盆栽 DIY", "干花花环 手作体验"],
     ["韩式花束+花篮设计，零基础可学", "3小时极速配送，可指定花材+配色", "多肉拼盆+微景观瓶，含工具材料", "进口干花+尤加利叶，可保存1年以上"],
     ["花点时间", ["野兽派"], "超级植物", "花治"],
     ["报名预约", "立即下单", "了解详情", "限时优惠"],
     [("文化", "category"), ("文艺", "style"), ("都市丽人", "audience"), ("周末出行", "scene")]),

    ("local", "escape room puzzle game", "board game cafe tabletop gaming",
     ["沉浸式密室逃脱 2h", "剧本杀 城市限定本", "桌游吧 畅玩3小时", "VR体验馆 1小时通票"],
     ["盗墓主题，机械机关+真人NPC互动", "6人本《年轮》变格推理，含服装道具", "500+正版桌游库+规则讲解", "VR射击+赛车+节奏光剑三合一"],
     ["X先生密室", "我是谜", "游人码头", "Sandbox VR"],
     ["立即预约", "查看剧本", "了解详情", "报名参与"],
     [("娱乐", "category"), ("社交", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("local", "nail art beauty salon", "hair salon barber shop interior",
     ["美甲美睫 闺蜜套餐", "日式烫染 设计师店", "男士理容 BarberShop", "韩式半永久定妆"],
     ["光疗纯色美甲+自然款嫁接睫毛", "资生堂烫染药水+Olaplex护发", "渐变理发+热敷剃须+修眉修面", "自然款雾眉+美瞳线+水晶唇"],
     ["InNail", "TONI&GUY", "TwoFace", "韩尚"],
     ["预约到店", "查看设计师", "了解详情", "限时优惠"],
     [("美妆", "category"), ("时尚", "style"), ("都市丽人", "audience"), ("周末出行", "scene")]),

    ("local", "pet store puppy dog supplies", "pet grooming cat boarding daycare",
     ["宠物美容 全套SPA", "宠物寄养 家庭式", "宠物医院 体检套餐", "狗狗日托班 单日体验"],
     ["洗护+拉毛+修剪+SPA精油护理", "家庭环境散养不关笼，视频每日反馈", "血液检查+B超+X光+传染病筛查", "社会化训练+户外活动+基础服从教学"],
     ["PetSmart", "宠爱国际", "瑞鹏宠物医院", "汪星人"],
     ["预约到店", "立即预约", "了解详情", "限时优惠"],
     [("宠物", "category"), ("简约", "style"), ("铲屎官", "audience"), ("周末出行", "scene")]),

    ("local", "barbecue bbq restaurant", "grill steak restaurant dining",
     ["炭火烤肉 4人拼盘", "韩式烤肉 畅吃", "日式烧肉 会席", "露台BBQ 夏日派对"],
     ["澳洲M5和牛+伊比利亚猪五花+厚切牛舌", "牛五花+猪梅肉+大虾+蔬菜拼盘无限续", "近江牛+海胆+时令海鲜，8道菜会席", "天台露台+烧烤炉租赁+食材套餐"],
     ["牛角", ["姜虎东"], "老乾杯", "屋顶BBQ"],
     ["预约餐位", "查看菜单", "排队取号", "立即预约"],
     [("餐饮", "category"), ("社交", "style"), ("聚会达人", "audience"), ("聚会", "scene")]),

    ("local", "concert live music stage", "music festival crowd outdoor",
     ["Livehouse 独立乐队演出", "爵士之夜 现场演出", "户外音乐节 早鸟票", "沉浸式光影音乐厅"],
     ["周五晚8点，三支本地独立乐队拼盘", "钢琴+贝斯+鼓三重奏+红酒小食", "2日通票+露营区+创意市集", "360°投影+弦乐四重奏+香氛体验"],
     ["MAO Livehouse", "BlueNote", "草莓音乐节", "teamLab"],
     ["立即购票", "查看阵容", "了解详情", "限时优惠"],
     [("娱乐", "category"), ("文艺", "style"), ("文艺青年", "audience"), ("周末出行", "scene")]),

    ("local", "swimming pool indoor water", "water park swimming pool",
     ["恒温游泳馆 月卡", "亲子游泳课 体验", "无边泳池 单次入场", "跳水池 自由练习"],
     ["28°C恒温+臭氧消毒+6泳道50米", "0-6岁，专业教练，亲子互动", "高空天际泳池，城市景观尽收眼底", "1m/3m/5m跳台+跳板，需深水证"],
     ["水立方", "蓝旗亲子游泳", "天际泳池", "跳水馆"],
     ["立即预约", "了解详情", "限时优惠", "报名参与"],
     [("运动", "category"), ("简约", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("local", "supermarket grocery store", "fresh food market grocery",
     ["进口食品节 全场8折", "农贸市场 赶集日", "有机食材 每周配送", "零食折扣店 开业特惠"],
     ["日韩欧美进口零食/饮料/调味料", "本地农民直供蔬菜水果+现杀活禽", "有机认证蔬菜+土鸡蛋+冷榨油品", "临期零食低至1折，日期新鲜看得见"],
     ["山姆会员店", "本地菜市场", "春播", "好特卖"],
     ["查看门店", "立即下单", "了解详情", "加入购物车"],
     [("购物", "category"), ("简约", "style"), ("家庭食客", "audience"), ("周末出行", "scene")]),

    ("local", "museum art gallery exhibition", "art exhibition gallery painting",
     ["当代艺术展 早鸟票", "沉浸式数字艺术展", "历史文物特展", "摄影展 获奖作品"],
     ["3位国际艺术家联展+装置艺术+油画", "光影互动+VR体验+全景投影空间", "三星堆文物+青铜器+金器+玉器", "世界新闻摄影大赛获奖作品巡展"],
     ["UCCA尤伦斯", "遇见博物馆", ["国家博物馆"], "谢子龙影像馆"],
     ["立即购票", "了解详情", "限时优惠", "预约参观"],
     [("文化", "category"), ("文艺", "style"), ("文艺青年", "audience"), ("周末出行", "scene")]),

    ("local", "ice cream dessert gelato shop", "dessert cake pastry bakery shop",
     ["手工冰淇淋 季节限定", "法式甜品 下午茶", "舒芙蕾 现烤出炉", "中式糖水 6款拼盘"],
     ["开心果+西西里柠檬+皮埃蒙特榛子", "马卡龙+歌剧院+慕斯杯+茶/咖啡", "原味/抹茶/提拉米苏，云朵般蓬松", "双皮奶+杨枝甘露+芝麻糊+红豆沙"],
     ["Venchi", "Angelina", "Flippers", "满记甜品"],
     ["到店消费", "立即下单", "预约餐位", "限时优惠"],
     [("餐饮", "category"), ("时尚", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("local", "rock climbing gym indoor", "climbing wall bouldering indoor",
     ["攀岩馆 单次体验", "抱石入门课 90min", "绳索攀岩 高阶课", "亲子攀岩 1大1小"],
     ["含装备租赁+安全讲解，无经验可玩", "基础技巧+线路解读+安全坠落", "先锋攀+多段结组+救援技术", "儿童专属岩壁+专业教练保护"],
     ["岩时攀岩", "Boulderhood", "首攀攀岩", "ClimbKids"],
     ["免费体验", "预约课程", "立即报名", "了解详情"],
     [("运动", "category"), ("社交", "style"), ("运动爱好者", "audience"), ("健身", "scene")]),

    ("local", "fruit market fresh produce stand", "organic farmers market fresh food",
     ["水果采摘 周末活动", "水果礼盒 节日限定", "社区菜站 每日新鲜", "热带水果 产地直发"],
     ["草莓/樱桃/葡萄当季采摘，入园畅吃", "日本晴王葡萄+新西兰奇异果+秘鲁蓝莓", "当季蔬菜+散养鸡蛋+现磨豆腐", "海南芒果+泰国榴莲+台湾凤梨"],
     ["采摘园", "百果园", "钱大妈", "盒马"],
     ["立即预约", "查看门店", "加入购物车", "限时优惠"],
     [("购物", "category"), ("简约", "style"), ("家庭食客", "audience"), ("周末出行", "scene")]),

    ("local", "sports bar pub beer", "bar cocktail lounge nightlife",
     ["精酿啤酒吧 品鉴套餐", "空中酒廊 城市夜景", ["威士忌吧 单一麦芽"], "日式清吧 一期一会"],
     ["6款自酿IPA+世涛+酸啤品鉴杯各100ml", "露天露台360°城市夜景+鸡尾酒", "200+款威士忌，专业品鉴师带领", "日式调酒+爵士乐+深夜食堂小食"],
     ["悠航精酿", "国贸空中酒廊", "Whisky Bar", "Bar Benfiddich"],
     ["预约座位", "立即预约", "查看菜单", "了解详情"],
     [("餐饮", "category"), ("社交", "style"), ("聚会达人", "audience"), ("聚会", "scene")]),

    ("local", "karaoke singing room entertainment", "karaoke party room interior",
     ["KTV 欢唱3小时 4人", "主题包厢 生日派对", "迷你KTV 10分钟体验", "家庭KTV 亲子房"],
     ["海量曲库+高清触屏+专业音响+果盘", "气球布置+生日蛋糕+香槟+定制MV", "扫码即唱+耳机监听+录制分享", "儿歌曲库+卡通主题包厢+安全音量"],
     ["纯K", "温莎", "唱吧", "酷秀"],
     ["预约包厢", "立即预约", "扫码体验", "了解详情"],
     [("娱乐", "category"), ("社交", "style"), ("学生党", "audience"), ("聚会", "scene")]),

    ("local", "park garden outdoor nature", "botanical garden flowers nature walk",
     ["城市公园 周末野餐", "植物园 花季特展", ["湿地公园 观鸟活动"], "城市骑行道 周末活动"],
     ["湖畔草坪+吊床区+户外烧烤炉租赁", "樱花/郁金香/绣球花季限定+拍照打卡", "望远镜租赁+鸟类专家带队+户外课堂", "城市绿道30km+沿途咖啡补给站"],
     ["奥林匹克公园", "植物园", "野鸭湖湿地", "城市绿道"],
     ["了解详情", "立即预约", "报名参与", "限时优惠"],
     [("旅行", "category"), ("文艺", "style"), ("亲子家庭", "audience"), ("周末出行", "scene")]),
]


def search_pexels(query: str, orientation: str = "portrait", per_page: int = 4) -> list[dict]:
    """搜索 Pexels 图片，返回照片列表。"""
    params = urllib.parse.urlencode({
        "query": query,
        "orientation": orientation,
        "per_page": per_page,
    })
    url = f"https://api.pexels.com/v1/search?{params}"
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        "Authorization": API_KEY,
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            data = json.loads(resp.read())
        return data.get("photos", [])
    except Exception as e:
        print(f"    API 错误: {e}")
        return []


def create_database(db_path: str):
    """创建 SQLite 数据库及表结构。"""
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    conn.execute("""
    CREATE TABLE IF NOT EXISTS ad_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        image_url TEXT NOT NULL,
        video_url TEXT,
        card_type TEXT NOT NULL,
        channel TEXT NOT NULL,
        sponsor TEXT NOT NULL,
        cta_text TEXT NOT NULL,
        ai_summary TEXT,
        creative_format TEXT,
        creative_emotion TEXT,
        industry TEXT,
        platform TEXT,
        ctr REAL,
        conversion_rate REAL,
        budget REAL,
        target_audience TEXT
    );
    """)

    conn.execute("""
    CREATE TABLE IF NOT EXISTS ad_tags (
        id TEXT PRIMARY KEY,
        ad_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
    );
    """)

    conn.execute("""
    CREATE TABLE IF NOT EXISTS interaction_states (
        ad_id TEXT PRIMARY KEY,
        is_liked INTEGER NOT NULL DEFAULT 0,
        is_collected INTEGER NOT NULL DEFAULT 0,
        like_count INTEGER NOT NULL DEFAULT 0,
        share_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
    );
    """)

    conn.execute("""
    CREATE TABLE IF NOT EXISTS analytics_events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        ad_id TEXT,
        channel TEXT,
        timestamp REAL NOT NULL,
        metadata TEXT
    );
    """)

    conn.commit()
    return conn


def insert_ad(conn, ad_id, title, desc, image_url, card_type, channel, sponsor, cta, tags):
    """插入一条广告及其标签。"""
    conn.execute("""
    INSERT OR REPLACE INTO ad_items (id, title, description, image_url, video_url, card_type, channel, sponsor, cta_text)
    VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?)
    """, (ad_id, title, desc, image_url, card_type, channel, sponsor, cta))

    for tag_name, tag_cat in tags:
        tag_id = f"{ad_id}_tag_{tag_name}"
        conn.execute(
            "INSERT OR REPLACE INTO ad_tags (id, ad_id, name, category) VALUES (?, ?, ?, ?)",
            (tag_id, ad_id, tag_name, tag_cat)
        )


def main():
    total_ads = 0
    print(f"开始爬取广告数据，共 {len(AD_CONCEPTS)} 个概念，每个最多 4 张图片...\n")

    conn = create_database(OUTPUT_PATH)

    for concept_idx, concept in enumerate(AD_CONCEPTS):
        channel, query, fallback, titles, descs, sponsors, ctas, tags_template = concept

        # 确保标题/描述/赞助商/CTA 是 4 个元素的列表
        def ensure_list4(val):
            """确保值为 4 个字符串的列表。若 val 本身是列表，展平并取前 4 个。"""
            if isinstance(val, list):
                flat = []
                for v in val:
                    if isinstance(v, list):
                        flat.extend(v)
                    else:
                        flat.append(v)
                if len(flat) >= 4:
                    return flat[:4]
                return (flat * 4)[:4]
            return [val] * 4

        titles4 = ensure_list4(titles)
        descs4 = ensure_list4(descs)
        sponsors4 = ensure_list4(sponsors)
        ctas4 = ensure_list4(ctas)

        print(f"[{concept_idx+1}/{len(AD_CONCEPTS)}] {query} ... ", end="", flush=True)

        photos = search_pexels(query, per_page=4)
        if len(photos) < 4 and fallback:
            extra = search_pexels(fallback, per_page=4 - len(photos))
            photos += extra

        if not photos:
            print("无结果，跳过")
            continue

        # 为该概念的每张照片各生成 1 条广告
        card_types = ["bigImage", "smallImage", "bigImage", "smallImage"]
        for i, photo in enumerate(photos[:4]):
            ad_id = f"{channel[:4]}_{concept_idx:02d}_{i}"
            image_url = photo["src"]["large"]
            insert_ad(conn,
                ad_id=ad_id,
                title=titles4[i],
                desc=descs4[i],
                image_url=image_url,
                card_type=card_types[i],
                channel=channel,
                sponsor=sponsors4[i],
                cta=ctas4[i],
                tags=tags_template,
            )
            total_ads += 1

        photos_count = min(len(photos), 4)
        print(f"{photos_count} 张图片 ✓")
        time.sleep(0.6)  # 遵守 API 频率限制

    conn.commit()
    conn.close()

    print(f"\n{'='*50}")
    print(f"完成！共创建 {total_ads} 条广告")
    print(f"输出: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
