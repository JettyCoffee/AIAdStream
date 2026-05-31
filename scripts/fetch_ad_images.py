#!/usr/bin/env python3
"""
使用 DeepSeek LLM 生成 450 条广告内容，结合 Pexels 图片和统一视频 URL，
生成 SQLite 种子数据库。

输出：AIAdStream/Resources/seed_ads.sqlite
规模：450 条广告（大图150 + 小图150 + 视频150），3 个频道各 150 条
"""

from typing import Dict, List, Optional

import json
import time
import urllib.request
import urllib.parse
import ssl
import sqlite3
import os
import sys

# ── 配置 ──────────────────────────────────────────────────
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE = "https://api.deepseek.com/v1/chat/completions"
PEXELS_API_KEY = "vIl2Ywc17zgKun3PLecxsVwhwDmYEPNMc2V9WOx49dVdMVAlDHsyveP2"

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "AIAdStream", "Resources")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "seed_ads.sqlite")

# 统一视频素材 URL（约 15 秒短视频，Google 官方样例）
VIDEO_URLS = [
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
    "https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
]

# ── 广告概念主题（每频道 50 个话题方向） ─────────────────

# featured: 科技数码、运动户外、美妆护肤、服饰时尚、家居生活、汽车出行、美食、旅行、母婴、宠物
FEATURED_TOPICS = [
    # 科技数码 (10 话题)
    "降噪耳机", "折叠屏手机", "智能手表", "轻薄笔记本", "微单相机",
    "机械键盘", "电竞鼠标", "平板电脑", "智能音箱", "VR头显",
    # 运动户外 (5 话题)
    "碳板跑鞋", "瑜伽服", "户外冲锋衣", "公路自行车", "露营帐篷",
    # 美妆护肤 (5 话题)
    "精华液", "香水", "吹风机", "防晒霜", "面膜",
    # 服饰时尚 (5 话题)
    "机械腕表", "设计师手袋", "太阳镜", "羊绒围巾", "运动鞋",
    # 家居生活 (5 话题)
    "扫地机器人", "咖啡机", "人体工学椅", "香薰机", "落地灯",
    # 汽车出行 (5 话题)
    "电动汽车", "电动滑板车", "行车记录仪", "车载净化器", "智能后视镜",
    # 美食 (5 话题)
    "巧克力礼盒", "威士忌", "日料", "牛排", "冰淇淋",
    # 旅行 (5 话题)
    "度假酒店", "登机箱", "旅行背包", "颈枕", "翻译机",
    # 母婴+宠物 (5 话题)
    "婴儿推车", "儿童玩具", "猫粮", "狗窝", "宠物零食",
]

ECOMMERCE_TOPICS = [
    # 美妆个护 (10 话题)
    "面霜", "口红", "眼影盘", "洗面奶", "身体乳",
    "护手霜", "卸妆油", "眉笔", "腮红", "定妆喷雾",
    # 食品零食 (8 话题)
    "坚果礼盒", "巧克力", "蛋白棒", "咖啡豆", "茶叶",
    "蜂蜜", "薯片", "牛肉干",
    # 数码配件 (8 话题)
    "充电器", "数据线", "充电宝", "手机壳", "蓝牙耳机",
    "屏幕膜", "支架", "读卡器",
    # 家居厨房 (8 话题)
    "空气炸锅", "破壁机", "保温杯", "炒锅", "刀具",
    "收纳盒", "拖把", "毛巾",
    # 服饰配件 (8 话题)
    "T恤", "牛仔裤", "袜子", "拖鞋", "帽子",
    "皮带", "雨伞", "手套",
    # 健康保健 (8 话题)
    "维生素", "蛋白粉", "鱼油", "益生菌", "枸杞",
    "按摩仪", "足浴盆", "血压计",
]

LOCAL_TOPICS = [
    # 餐饮美食 (12 话题)
    "火锅", "烤肉", "奶茶", "咖啡", "面包房",
    "日料", "烧烤", "甜品", "面馆", "自助餐",
    "小龙虾", "素食",
    # 休闲娱乐 (10 话题)
    "电影院", "密室逃脱", "KTV", "桌游吧", "livehouse",
    "剧本杀", "VR体验", "保龄球", "台球", "卡丁车",
    # 运动健身 (8 话题)
    "健身房", "瑜伽馆", "游泳馆", "攀岩馆", "拳击馆",
    "舞蹈室", "羽毛球", "滑雪场",
    # 生活服务 (10 话题)
    "美甲", "理发店", "SPA按摩", "花店", "宠物美容",
    "洗车", "摄影工作室", "洗衣店", "搬家", "家政",
    # 文化展览 (5 话题)
    "美术馆", "博物馆", "书店", "花市", "创意市集",
    # 购物 (5 话题)
    "商场", "便利店", "水果店", "菜市场", "折扣店",
]

# ── LLM 内容生成 ─────────────────────────────────────────

SYSTEM_PROMPT = """你是一个专业的广告创意文案，需要为广告信息流 App 批量生成中文广告内容。

要求：
1. 输出严格 JSON 数组，每个元素代表一则广告
2. 每个元素包含字段：title, description, aiSummary, sponsor, tags
3. title：产品/服务名称，10-20字
4. description：商品/服务详细介绍，200-300字，生动有吸引力，突出卖点
5. aiSummary：一句话推荐语，20-40字
6. sponsor：品牌商名称，中文或英文，2-12字
7. tags：包含三个标签的对象 {category, style, audience}
   - category：品类标签，≤3个字（如：数码、美妆、运动、餐饮、汽车、家居）
   - style：风格标签，≤3个字（如：科技、简约、时尚、经典、文艺、社交）
   - audience：受众标签，≤3个字（如：上班族、学生党、宝妈、都市丽人、运动爱好者）

请确保：
- description 必须超过 200 字
- 每个 tag 的 value 不超过 3 个字
- 广告内容多样，不重复
- 直接输出 JSON 数组，不要 markdown 包裹"""


def generate_ad_content(topics: List[str], channel: str, batch_size: int = 10) -> List[Dict]:
    """调用 DeepSeek API 批量生成广告内容。"""
    if not DEEPSEEK_API_KEY:
        print("⚠️  未设置 DEEPSEEK_API_KEY 环境变量，无法调用 LLM")
        sys.exit(1)

    user_prompt = f"""请为「{channel}」频道生成 {len(topics)} 组广告文案。

每组包含 3 条广告变体（对应大图、小图、视频三种卡片类型），话题分别如下：
{chr(10).join(f"{i+1}. {t}" for i, t in enumerate(topics))}

共 {len(topics) * 3} 条广告。请确保每条广告的 description 超过 200 字，tag 值不超过 3 个字。"""

    body = {
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.9,
        "max_tokens": 8192,
        "stream": False,
    }

    ctx = ssl.create_default_context()
    req = urllib.request.Request(
        DEEPSEEK_BASE,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    max_retries = 3
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
                data = json.loads(resp.read())
            content = data["choices"][0]["message"]["content"]

            # 清理可能的 markdown 包裹
            content = content.strip()
            if content.startswith("```"):
                lines = content.split("\n")
                content = "\n".join(lines[1:-1])

            ads = json.loads(content)
            if isinstance(ads, dict) and "ads" in ads:
                ads = ads["ads"]
            if not isinstance(ads, list):
                print(f"  ⚠️  LLM 返回格式异常: {type(ads)}")
                return []
            return ads
        except (json.JSONDecodeError, KeyError, IndexError) as e:
            print(f"  ⚠️  解析失败 (尝试 {attempt+1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(3)
        except Exception as e:
            print(f"  ⚠️  API 错误 (尝试 {attempt+1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(5)

    return []


# ── Pexels 图片搜索 ───────────────────────────────────────

def search_pexels(query: str, per_page: int = 5) -> List[Dict]:
    """搜索 Pexels 图片。"""
    params = urllib.parse.urlencode({
        "query": query,
        "orientation": "portrait",
        "per_page": per_page,
    })
    url = f"https://api.pexels.com/v1/search?{params}"
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        "Authorization": PEXELS_API_KEY,
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            data = json.loads(resp.read())
        return data.get("photos", [])
    except Exception as e:
        print(f"    Pexels API 错误: {e}")
        return []


# ── 数据库操作 ─────────────────────────────────────────────

def create_database(db_path: str) -> sqlite3.Connection:
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
        ai_summary TEXT NOT NULL
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


def insert_ad(conn: sqlite3.Connection, ad_id: str, ad_data: Dict,
              image_url: str, video_url: Optional[str],
              card_type: str, channel: str):
    """插入一条广告及其标签。"""
    desc = ad_data.get("description", "")
    # 确保 description 超过 200 字
    if len(desc) < 200:
        desc = desc + "。" + "品质卓越，用户体验极佳，深受广大消费者喜爱与信赖。" * 5
        desc = desc[:300]

    conn.execute("""
    INSERT OR REPLACE INTO ad_items (id, title, description, image_url, video_url, card_type, channel, sponsor, ai_summary)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        ad_id,
        ad_data.get("title", "广告标题"),
        desc,
        image_url,
        video_url,
        card_type,
        channel,
        ad_data.get("sponsor", "品牌商"),
        ad_data.get("aiSummary", "值得推荐的好产品"),
    ))

    tags = ad_data.get("tags", {})
    tag_map = {
        "category": tags.get("category", "好物"),
        "style": tags.get("style", "简约"),
        "audience": tags.get("audience", "大众"),
    }
    for cat, name in tag_map.items():
        # 确保 tag 不超过 3 字
        name = name[:3] if len(name) > 3 else name
        tag_id = f"{ad_id}_tag_{name}"
        conn.execute(
            "INSERT OR REPLACE INTO ad_tags (id, ad_id, name, category) VALUES (?, ?, ?, ?)",
            (tag_id, ad_id, name, cat)
        )


# ── 主流程 ────────────────────────────────────────────────

def main():
    if not DEEPSEEK_API_KEY:
        print("=" * 60)
        print("错误：请设置 DEEPSEEK_API_KEY 环境变量")
        print("示例：export DEEPSEEK_API_KEY=sk-xxx")
        print("=" * 60)
        sys.exit(1)

    start_time = time.time()
    print("=" * 60)
    print("AIAdStream 种子数据库生成器 v3")
    print(f"目标：450 条广告（大图150 + 小图150 + 视频150）")
    print(f"频道：featured / ecommerce / local 各 150 条")
    print("=" * 60)

    # 清理旧数据库
    if os.path.exists(OUTPUT_PATH):
        os.remove(OUTPUT_PATH)
        print(f"\n已删除旧数据库: {OUTPUT_PATH}")

    conn = create_database(OUTPUT_PATH)
    total_ads = 0
    ad_index = 0  # 全局广告序号

    channel_configs = [
        ("featured", FEATURED_TOPICS, "featured"),
        ("ecommerce", ECOMMERCE_TOPICS, "ecommerce"),
        ("local", LOCAL_TOPICS, "local"),
    ]

    for channel_key, topics, channel_name in channel_configs:
        print(f"\n{'─' * 50}")
        print(f"📡 开始生成 {channel_name} 频道广告 ({len(topics)} 个话题 × 3 = {len(topics)*3} 条)")
        print(f"{'─' * 50}")

        # 批量调用 LLM 生成内容（每次 5 个话题 → 15 条广告）
        batch_size = 5
        all_content = []
        for batch_start in range(0, len(topics), batch_size):
            batch_topics = topics[batch_start:batch_start + batch_size]
            batch_num = batch_start // batch_size + 1
            total_batches = (len(topics) + batch_size - 1) // batch_size
            print(f"  [{batch_num}/{total_batches}] LLM 生成 {len(batch_topics)} 个话题 × 3 变体 ...", end=" ", flush=True)

            ads = generate_ad_content(batch_topics, channel_name)
            if ads:
                all_content.extend(ads)
                print(f"✓ 获得 {len(ads)} 条")
            else:
                print("✗ 失败")
            time.sleep(1)  # 避免 API 限流

        if len(all_content) < len(topics) * 3:
            print(f"  ⚠️  期望 {len(topics)*3} 条，实际获得 {len(all_content)} 条，将用默认数据填充")
            # 填充不足的数据
            shortfall = len(topics) * 3 - len(all_content)
            for i in range(shortfall):
                topic_idx = i % len(topics)
                all_content.append({
                    "title": f"{topics[topic_idx]}推荐 {i+1}",
                    "description": f"这是一款高品质的{topics[topic_idx]}产品，采用先进工艺和优质材料精心打造。经过严格质量检测，确保每一个细节都达到卓越标准。无论是外观设计还是使用体验，都经过反复打磨优化。适合追求品质生活的你，让日常变得更加便捷和美好。值得信赖的选择，带来超乎期待的满意体验。" * 2,
                    "aiSummary": f"{topics[topic_idx]}优选，品质有保障",
                    "sponsor": f"{channel_name[:4].capitalize()}Brand{ad_index}",
                    "tags": {"category": topics[topic_idx][:3], "style": "简约", "audience": "大众"},
                })

        # 确保正好 150 条（50 话题 × 3）
        all_content = all_content[:len(topics) * 3]

        # 为每个话题获取 Pexels 图片
        # 大图和小图需要图片，视频用统一 URL
        print(f"\n  📷 获取 Pexels 图片 ...")
        card_types_cycle = ["bigImage", "smallImage", "video"]
        image_cache = {}  # topic -> [image_urls]

        for topic_idx, topic in enumerate(topics):
            # 每个话题需要 2 张图片（给 bigImage 和 smallImage）
            if topic not in image_cache:
                photos = search_pexels(topic)
                if photos:
                    image_cache[topic] = [p["src"]["large"] for p in photos]
                else:
                    image_cache[topic] = []
            if (topic_idx + 1) % 10 == 0:
                print(f"    已获取 {topic_idx+1}/{len(topics)} 个话题的图片")
            time.sleep(0.3)

        # 插入数据
        print(f"\n  💾 写入数据库 ...")
        video_idx = 0
        for topic_idx, topic in enumerate(topics):
            photos = image_cache.get(topic, [])
            for variant in range(3):
                card_type = card_types_cycle[variant]
                content_idx = topic_idx * 3 + variant
                ad_data = all_content[content_idx]

                ad_id = f"{channel_key[:4]}_{ad_index:04d}"
                ad_index += 1

                if card_type == "video":
                    image_url = photos[0] if photos else f"https://images.pexels.com/photos/{100000 + topic_idx}/pexels-photo-{100000 + topic_idx}.jpeg"
                    video_url = VIDEO_URLS[video_idx % len(VIDEO_URLS)]
                    video_idx += 1
                else:
                    image_url = photos[variant % len(photos)] if photos else f"https://images.pexels.com/photos/{200000 + topic_idx * 2 + variant}/pexels-photo-{200000 + topic_idx * 2 + variant}.jpeg"
                    video_url = None

                insert_ad(conn, ad_id, ad_data, image_url, video_url, card_type, channel_key)
                total_ads += 1

        print(f"  ✅ {channel_name} 完成，累计 {total_ads} 条")

    conn.commit()
    conn.close()

    elapsed = time.time() - start_time
    print(f"\n{'=' * 60}")
    print(f"🎉 完成！共生成 {total_ads} 条广告")
    print(f"⏱️  耗时: {elapsed:.0f} 秒")
    print(f"📁 输出: {OUTPUT_PATH}")

    # 验证
    verify_db = sqlite3.connect(OUTPUT_PATH)
    counts = {}
    for table in ["ad_items", "ad_tags", "interaction_states", "analytics_events"]:
        counts[table] = verify_db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    verify_db.close()

    print(f"\n📊 数据库统计:")
    print(f"   ad_items:          {counts['ad_items']}")
    print(f"   ad_tags:           {counts['ad_tags']}")
    for ch in ["featured", "ecommerce", "local"]:
        ch_conn = sqlite3.connect(OUTPUT_PATH)
        for ct in ["bigImage", "smallImage", "video"]:
            cnt = ch_conn.execute(
                "SELECT COUNT(*) FROM ad_items WHERE channel=? AND card_type=?",
                (ch, ct)
            ).fetchone()[0]
            print(f"   {ch}/{ct}:  {cnt}")
        ch_conn.close()
    print(f"   interaction_states: {counts['interaction_states']}")
    print(f"   analytics_events:   {counts['analytics_events']}")


if __name__ == "__main__":
    main()
