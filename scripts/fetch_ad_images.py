#!/usr/bin/env python3
"""
从 Pexels API 为种子数据中的 39 条广告匹配真实图片。
输出 JSON 映射：ad_id → image_url，供 SeedDataGenerator 使用。
"""

import json
import time
import urllib.request
import urllib.parse
import ssl
import os

API_KEY = "vIl2Ywc17zgKun3PLecxsVwhwDmYEPNMc2V9WOx49dVdMVAlDHsyveP2"
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "AIAdStream", "Resources", "ad_images.json")

# ad_id → (搜索关键词, fallback关键词)
AD_QUERIES = {
    # === 发现频道 / Featured (15) ===
    "feat_0":  ("nike sneakers product", "nike air max"),
    "feat_1":  ("apple vision pro headset", "vr headset technology"),
    "feat_2":  ("sony camera photography", "mirrorless camera"),
    "feat_3":  ("nio electric car", "luxury electric vehicle"),
    "feat_4":  ("dyson hair styler", "hair styling tool"),
    "feat_5":  ("dji drone aerial", "drone photography"),
    "feat_6":  ("starbucks cold brew coffee", "iced coffee drink"),
    "feat_7":  ("tesla cybertruck", "electric pickup truck"),
    "feat_8":  ("uniqlo t-shirt clothing", "casual fashion clothing"),
    "feat_9":  ("bose headphones audio", "noise cancelling headphones"),
    "feat_10": ("lululemon yoga pants", "yoga athletic wear"),
    "feat_11": ("huawei smartphone", "mobile phone technology"),
    "feat_12": ("patagonia outdoor jacket", "hiking jacket outdoor"),
    "feat_13": ("lego technic car model", "lego building set"),
    "feat_14": ("airbnb travel accommodation", "cozy cabin interior"),

    # === 电商频道 / Ecommerce (12) ===
    "ec_0":  ("skincare product luxury", "facial serum skincare"),
    "ec_1":  ("chinese baijiu liquor", "premium liquor bottle"),
    "ec_2":  ("mixed nuts snack healthy", "dried fruit nuts"),
    "ec_3":  ("usb charger gan", "power charger technology"),
    "ec_4":  ("air fryer kitchen appliance", "kitchen cooking appliance"),
    "ec_5":  ("floral dress fashion", "summer dress women fashion"),
    "ec_6":  ("nintendo switch gaming", "video game console"),
    "ec_7":  ("skincare serum beauty", "facial moisturizer product"),
    "ec_8":  ("dyson vacuum cleaner", "cordless vacuum home"),
    "ec_9":  ("eyeshadow makeup palette", "cosmetics makeup product"),
    "ec_10": ("aroma diffuser home", "essential oil diffuser minimal"),
    "ec_11": ("pour over coffee maker", "manual coffee brewing"),

    # === 本地频道 / Local (12) ===
    "local_0":  ("hotpot restaurant food", "chinese hotpot dining"),
    "local_1":  ("luxury shopping mall", "department store luxury"),
    "local_2":  ("peloton exercise bike", "indoor cycling fitness"),
    "local_3":  ("bubble tea drink", "milk tea beverage"),
    "local_4":  ("convenience store interior", "japanese convenience store"),
    "local_5":  ("gym fitness interior", "fitness studio workout"),
    "local_6":  ("nio car showroom", "electric car showroom modern"),
    "local_7":  ("fresh seafood market", "supermarket fresh food"),
    "local_8":  ("universal studios theme park", "amusement park roller coaster"),
    "local_9":  ("fitness personal training", "gym workout training"),
    "local_10": ("bookstore coffee shop", "cozy bookstore reading"),
    "local_11": ("bookstore reading space", "library bookstore interior"),
}


def search_pexels(query: str, orientation: str = "portrait", per_page: int = 3) -> list[dict]:
    """搜索 Pexels 图片，返回照片列表。"""
    params = urllib.parse.urlencode({
        "query": query,
        "orientation": orientation,
        "per_page": per_page,
    })
    url = f"https://api.pexels.com/v1/search?{params}"

    # macOS Python 3.9 需要处理 SSL
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        "Authorization": API_KEY,
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, context=ctx) as resp:
        data = json.loads(resp.read())
    return data.get("photos", [])


def main():
    print(f"共 {len(AD_QUERIES)} 条广告需要匹配图片\n")

    results = {}
    failed = []

    for ad_id, (primary_query, fallback_query) in AD_QUERIES.items():
        print(f"[{ad_id}] 搜索: {primary_query} ... ", end="", flush=True)

        photos = search_pexels(primary_query)

        if not photos and fallback_query:
            print(f"无结果，尝试: {fallback_query} ... ", end="", flush=True)
            photos = search_pexels(fallback_query)

        if not photos:
            print("❌ 未找到图片")
            failed.append(ad_id)
            continue

        photo = photos[0]
        image_url = photo["src"]["large"]
        photographer = photo["photographer"]
        photo_id = photo["id"]
        alt = photo.get("alt", "")

        results[ad_id] = {
            "url": image_url,
            "photographer": photographer,
            "photo_id": photo_id,
            "alt": alt,
        }
        print(f"✓ photo:{photo_id} by {photographer}")

        # 遵守 API 频率限制（200 req/h ≈ 每 18 秒一次是安全的，但实际可以更快）
        time.sleep(0.5)

    # 写入结果
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n{'='*50}")
    print(f"成功: {len(results)}/{len(AD_QUERIES)}")
    if failed:
        print(f"失败: {failed}")
    print(f"输出: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
