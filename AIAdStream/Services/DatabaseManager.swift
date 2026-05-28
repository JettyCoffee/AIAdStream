import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aiadstream.db", qos: .userInitiated)

    private init() {
        openDatabase()
        createTables()
        seedIfNeeded()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = docsDir.appendingPathComponent("aiadstream.sqlite").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            fatalError("Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
        }

        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)
    }

    private func createTables() {
        let createAdsTable = """
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
        """

        let createTagsTable = """
        CREATE TABLE IF NOT EXISTS ad_tags (
            id TEXT PRIMARY KEY,
            ad_id TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
        );
        """

        let createInteractionsTable = """
        CREATE TABLE IF NOT EXISTS interaction_states (
            ad_id TEXT PRIMARY KEY,
            is_liked INTEGER NOT NULL DEFAULT 0,
            is_collected INTEGER NOT NULL DEFAULT 0,
            like_count INTEGER NOT NULL DEFAULT 0,
            share_count INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
        );
        """

        let createAnalyticsTable = """
        CREATE TABLE IF NOT EXISTS analytics_events (
            id TEXT PRIMARY KEY,
            event_type TEXT NOT NULL,
            ad_id TEXT,
            channel TEXT,
            timestamp REAL NOT NULL,
            metadata TEXT
        );
        """

        let statements = [createAdsTable, createTagsTable, createInteractionsTable, createAnalyticsTable]
        for sql in statements {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    private static let seedVersionKey = "com.aiadstream.seed_version"
    /// 当前种子数据版本号，升级种子库时递增
    private static let currentSeedVersion = 2

    private func seedIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        let adCount = executeScalar("SELECT COUNT(*) FROM ad_items")
        let needsSeed = adCount == 0 || (storedVersion < Self.currentSeedVersion && adCount > 0)

        guard needsSeed else {
            print("[DB] Seed up-to-date (version \(storedVersion), \(adCount) ads)")
            return
        }

        if adCount > 0 {
            print("[DB] Re-seeding: clearing \(adCount) old ads for version \(storedVersion) → \(Self.currentSeedVersion)")
            executeUpdate("DELETE FROM ad_tags") { _ in }
            executeUpdate("DELETE FROM ad_items") { _ in }
        }

        guard let seedURL = Bundle.main.url(forResource: "seed_ads", withExtension: "sqlite") else {
            print("[DB] ERROR: seed_ads.sqlite not found in bundle. Bundle resources: \(Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil) ?? [])")
            return
        }

        print("[DB] Found seed database at: \(seedURL.path)")

        var seedDB: OpaquePointer?
        guard sqlite3_open(seedURL.path, &seedDB) == SQLITE_OK else {
            print("[DB] ERROR: Failed to open seed database")
            return
        }
        defer { sqlite3_close(seedDB) }

        guard let db = db else {
            print("[DB] ERROR: Working database not open")
            return
        }

        // BEGIN TRANSACTION for performance
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        var totalAds = 0
        var totalTags = 0

        // 导入广告数据
        var queryStmt: OpaquePointer?
        if sqlite3_prepare_v2(seedDB,
            "SELECT id, title, description, image_url, video_url, card_type, channel, sponsor, cta_text FROM ad_items",
            -1, &queryStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(queryStmt) }

            while sqlite3_step(queryStmt) == SQLITE_ROW {
                var insertStmt: OpaquePointer?
                let sql = "INSERT INTO ad_items (id, title, description, image_url, video_url, card_type, channel, sponsor, cta_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
                if sqlite3_prepare_v2(db, sql, -1, &insertStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(insertStmt) }
                    for i in 0..<9 {
                        if sqlite3_column_type(queryStmt, Int32(i)) == SQLITE_NULL {
                            sqlite3_bind_null(insertStmt, Int32(i + 1))
                        } else {
                            sqlite3_bind_text(insertStmt, Int32(i + 1), sqlite3_column_text(queryStmt, Int32(i)), -1, nil)
                        }
                    }
                    if sqlite3_step(insertStmt) == SQLITE_DONE { totalAds += 1 }
                }
            }
        }

        // 导入标签数据
        var tagStmt: OpaquePointer?
        if sqlite3_prepare_v2(seedDB, "SELECT id, ad_id, name, category FROM ad_tags", -1, &tagStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(tagStmt) }

            while sqlite3_step(tagStmt) == SQLITE_ROW {
                var insertStmt: OpaquePointer?
                let sql = "INSERT INTO ad_tags (id, ad_id, name, category) VALUES (?, ?, ?, ?)"
                if sqlite3_prepare_v2(db, sql, -1, &insertStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(insertStmt) }
                    for i in 0..<4 {
                        sqlite3_bind_text(insertStmt, Int32(i + 1), sqlite3_column_text(tagStmt, Int32(i)), -1, nil)
                    }
                    if sqlite3_step(insertStmt) == SQLITE_DONE { totalTags += 1 }
                }
            }
        }

        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        UserDefaults.standard.set(Self.currentSeedVersion, forKey: Self.seedVersionKey)
        print("[DB] Seeded \(totalAds) ads with \(totalTags) tags (version \(Self.currentSeedVersion))")
    }

    // MARK: - Ad Queries

    func fetchAds(channel: String, offset: Int, limit: Int, tagFilter: String? = nil) -> (ads: [AdItem], total: Int) {
        var ads: [AdItem] = []
        var total = 0

        dbQueue.sync {
            var sql = "SELECT COUNT(*) FROM ad_items WHERE channel = ?"
            if tagFilter != nil {
                sql = """
                SELECT COUNT(DISTINCT a.id) FROM ad_items a
                JOIN ad_tags t ON a.id = t.ad_id
                WHERE a.channel = ? AND t.name = ?
                """
            }
            total = Int(executeScalar(sql, bind: { stmt in
                sqlite3_bind_text(stmt, 1, (channel as NSString).utf8String, -1, nil)
                if let tf = tagFilter {
                    sqlite3_bind_text(stmt, 2, (tf as NSString).utf8String, -1, nil)
                }
            }))

            var querySQL = "SELECT * FROM ad_items WHERE channel = ? ORDER BY id LIMIT ? OFFSET ?"
            if tagFilter != nil {
                querySQL = """
                SELECT DISTINCT a.* FROM ad_items a
                JOIN ad_tags t ON a.id = t.ad_id
                WHERE a.channel = ? AND t.name = ?
                ORDER BY a.id LIMIT ? OFFSET ?
                """
            }
            ads = executeQuery(querySQL) { stmt in
                if tagFilter != nil {
                    sqlite3_bind_text(stmt, 1, (channel as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (tagFilter! as NSString).utf8String, -1, nil)
                    sqlite3_bind_int64(stmt, 3, Int64(limit))
                    sqlite3_bind_int64(stmt, 4, Int64(offset))
                } else {
                    sqlite3_bind_text(stmt, 1, (channel as NSString).utf8String, -1, nil)
                    sqlite3_bind_int64(stmt, 2, Int64(limit))
                    sqlite3_bind_int64(stmt, 3, Int64(offset))
                }
            }.map { rowToAdItem($0) }
        }

        return (ads, total)
    }

    func fetchAd(by id: String) -> AdItem? {
        var result: AdItem?
        dbQueue.sync {
            let rows = executeQuery("SELECT * FROM ad_items WHERE id = ?") { stmt in
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            }
            if let row = rows.first {
                result = rowToAdItem(row)
            }
        }
        return result
    }

    func allAds(for channel: String) -> [AdItem] {
        var result: [AdItem] = []
        dbQueue.sync {
            let rows = executeQuery("SELECT * FROM ad_items WHERE channel = ?") { stmt in
                sqlite3_bind_text(stmt, 1, (channel as NSString).utf8String, -1, nil)
            }
            result = rows.map { rowToAdItem($0) }
        }
        return result
    }

    func searchAds(query: String, channel: String?) -> [AdItem] {
        var result: [AdItem] = []
        dbQueue.sync {
            let searchPattern = "%\(query)%"
            var sql = """
            SELECT DISTINCT a.* FROM ad_items a
            LEFT JOIN ad_tags t ON a.id = t.ad_id
            WHERE (a.title LIKE ? OR a.description LIKE ? OR a.sponsor LIKE ?
               OR a.industry LIKE ? OR t.name LIKE ?)
            """
            var params: [String] = [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern]

            if let ch = channel {
                sql += " AND a.channel = ?"
                params.append(ch)
            }
            sql += " ORDER BY a.ctr DESC LIMIT 20"

            let rows = executeQuery(sql) { stmt in
                for (i, param) in params.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
                }
            }
            result = rows.map { rowToAdItem($0) }
        }
        return result
    }

    // MARK: - Tag Queries

    func tagsForAd(_ adId: String) -> [AITag] {
        var result: [AITag] = []
        dbQueue.sync {
            result = tagsForAdInternal(adId)
        }
        return result
    }

    private func tagsForAdInternal(_ adId: String) -> [AITag] {
        var result: [AITag] = []
        let rows = executeQuery("SELECT * FROM ad_tags WHERE ad_id = ?") { stmt in
            sqlite3_bind_text(stmt, 1, (adId as NSString).utf8String, -1, nil)
        }
        for row in rows {
            result.append(AITag(
                id: row["id"] as? String ?? "",
                name: row["name"] as? String ?? "",
                category: TagCategory(rawValue: row["category"] as? String ?? "category") ?? .category
            ))
        }
        return result
    }

    func allTags(for channel: String?) -> [String] {
        var result: [String] = []
        dbQueue.sync {
            var sql = "SELECT DISTINCT name FROM ad_tags"
            var params: [String] = []
            if let ch = channel {
                sql = """
                SELECT DISTINCT t.name FROM ad_tags t
                JOIN ad_items a ON t.ad_id = a.id
                WHERE a.channel = ?
                """
                params.append(ch)
            }
            let rows = executeQuery(sql) { stmt in
                for (i, param) in params.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
                }
            }
            result = rows.compactMap { $0["name"] as? String }
        }
        return result
    }

    func allTagsWithCategory(for channel: String?) -> [AITag] {
        var result: [AITag] = []
        dbQueue.sync {
            let sql: String
            var params: [String] = []
            if let ch = channel {
                sql = """
                SELECT DISTINCT t.name, t.category FROM ad_tags t
                JOIN ad_items a ON t.ad_id = a.id
                WHERE a.channel = ?
                """
                params.append(ch)
            } else {
                sql = "SELECT DISTINCT name, category FROM ad_tags"
            }
            let rows = executeQuery(sql) { stmt in
                for (i, param) in params.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
                }
            }
            result = rows.map { row in
                AITag(
                    id: UUID().uuidString,
                    name: row["name"] as? String ?? "",
                    category: TagCategory(rawValue: row["category"] as? String ?? "category") ?? .category
                )
            }
        }
        return result
    }

    // MARK: - Interaction Queries

    func loadInteractionState(for adId: String) -> InteractionState {
        var result = InteractionState()
        dbQueue.sync {
            let rows = executeQuery("SELECT * FROM interaction_states WHERE ad_id = ?") { stmt in
                sqlite3_bind_text(stmt, 1, (adId as NSString).utf8String, -1, nil)
            }
            if let row = rows.first {
                result = InteractionState(
                    isLiked: (row["is_liked"] as? Int64 ?? 0) != 0,
                    isCollected: (row["is_collected"] as? Int64 ?? 0) != 0,
                    likeCount: Int(row["like_count"] as? Int64 ?? 0),
                    shareCount: Int(row["share_count"] as? Int64 ?? 0)
                )
            }
        }
        return result
    }

    func saveInteractionState(_ state: InteractionState, for adId: String) {
        dbQueue.sync {
            executeUpdate("""
            INSERT OR REPLACE INTO interaction_states (ad_id, is_liked, is_collected, like_count, share_count)
            VALUES (?, ?, ?, ?, ?)
            """) { stmt in
                sqlite3_bind_text(stmt, 1, (adId as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, state.isLiked ? 1 : 0)
                sqlite3_bind_int(stmt, 3, state.isCollected ? 1 : 0)
                sqlite3_bind_int64(stmt, 4, Int64(state.likeCount))
                sqlite3_bind_int64(stmt, 5, Int64(state.shareCount))
            }
        }
    }

    func loadAllInteractionStates() -> [String: InteractionState] {
        var result: [String: InteractionState] = [:]
        dbQueue.sync {
            let rows = executeQuery("SELECT * FROM interaction_states", bind: nil)
            for row in rows {
                let adId = row["ad_id"] as? String ?? ""
                result[adId] = InteractionState(
                    isLiked: (row["is_liked"] as? Int64 ?? 0) != 0,
                    isCollected: (row["is_collected"] as? Int64 ?? 0) != 0,
                    likeCount: Int(row["like_count"] as? Int64 ?? 0),
                    shareCount: Int(row["share_count"] as? Int64 ?? 0)
                )
            }
        }
        return result
    }

    // MARK: - Analytics Queries

    func insertAnalyticsEvent(_ event: AnalyticsEvent) {
        dbQueue.sync {
            executeUpdate("""
            INSERT INTO analytics_events (id, event_type, ad_id, channel, timestamp, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            """) { stmt in
                sqlite3_bind_text(stmt, 1, (event.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (event.type.rawValue as NSString).utf8String, -1, nil)
                if let adId = event.adId {
                    sqlite3_bind_text(stmt, 3, (adId as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }
                if let channel = event.channel {
                    sqlite3_bind_text(stmt, 4, (channel as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                sqlite3_bind_double(stmt, 5, event.timestamp.timeIntervalSince1970)
                if let meta = event.metadata {
                    sqlite3_bind_text(stmt, 6, (meta as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
            }
        }
    }

    func fetchAnalyticsEvents() -> [AnalyticsEvent] {
        var result: [AnalyticsEvent] = []
        dbQueue.sync {
            let rows = executeQuery("SELECT * FROM analytics_events ORDER BY timestamp DESC", bind: nil)
            for row in rows {
                result.append(AnalyticsEvent(
                    id: row["id"] as? String ?? "",
                    type: AnalyticsEventType(rawValue: row["event_type"] as? String ?? "impression") ?? .impression,
                    adId: row["ad_id"] as? String,
                    channel: row["channel"] as? String,
                    timestamp: Date(timeIntervalSince1970: row["timestamp"] as? Double ?? 0),
                    metadata: row["metadata"] as? String
                ))
            }
        }
        return result
    }

    // MARK: - Low-level SQLite helpers

    private func insertAd(_ ad: AdItem) {
        executeUpdate("""
        INSERT OR REPLACE INTO ad_items (id, title, description, image_url, video_url, card_type, channel, sponsor, cta_text, ai_summary, creative_format, creative_emotion, industry, platform, ctr, conversion_rate, budget, target_audience)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """) { stmt in
            sqlite3_bind_text(stmt, 1, (ad.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (ad.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (ad.description as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (ad.imageURL as NSString).utf8String, -1, nil)
            if let vu = ad.videoURL {
                sqlite3_bind_text(stmt, 5, (vu as NSString).utf8String, -1, nil)
            } else { sqlite3_bind_null(stmt, 5) }
            sqlite3_bind_text(stmt, 6, (ad.cardType.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 7, (ad.channel.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 8, (ad.sponsor as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 9, (ad.ctaText as NSString).utf8String, -1, nil)
            if let summary = ad.aiSummary {
                sqlite3_bind_text(stmt, 10, (summary as NSString).utf8String, -1, nil)
            } else { sqlite3_bind_null(stmt, 10) }
            sqlite3_bind_null(stmt, 11) // creative_format
            sqlite3_bind_null(stmt, 12) // creative_emotion
            sqlite3_bind_null(stmt, 13) // industry
            sqlite3_bind_null(stmt, 14) // platform
            sqlite3_bind_null(stmt, 15) // ctr
            sqlite3_bind_null(stmt, 16) // conversion_rate
            sqlite3_bind_null(stmt, 17) // budget
            sqlite3_bind_null(stmt, 18) // target_audience
        }

        for tag in ad.tags {
            executeUpdate(
                "INSERT OR REPLACE INTO ad_tags (id, ad_id, name, category) VALUES (?, ?, ?, ?)"
            ) { stmt in
                sqlite3_bind_text(stmt, 1, (tag.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (ad.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (tag.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (tag.category.rawValue as NSString).utf8String, -1, nil)
            }
        }
    }

    private func rowToAdItem(_ row: [String: Any]) -> AdItem {
        let adId = row["id"] as? String ?? ""
        return AdItem(
            id: adId,
            title: row["title"] as? String ?? "",
            description: row["description"] as? String ?? "",
            imageURL: row["image_url"] as? String ?? "",
            videoURL: row["video_url"] as? String,
            cardType: AdCardType(rawValue: row["card_type"] as? String ?? "bigImage") ?? .bigImage,
            channel: Channel(rawValue: row["channel"] as? String ?? "featured") ?? .featured,
            tags: tagsForAdInternal(adId),
            aiSummary: row["ai_summary"] as? String,
            sponsor: row["sponsor"] as? String ?? "",
            ctaText: row["cta_text"] as? String ?? "了解详情"
        )
    }

    private func executeScalar(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> Int64 {
        var stmt: OpaquePointer?
        var result: Int64 = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind?(stmt!)
            if sqlite3_step(stmt!) == SQLITE_ROW {
                result = sqlite3_column_int64(stmt!, 0)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func executeQuery(_ sql: String, bind: ((OpaquePointer) -> Void)?) -> [[String: Any]] {
        var results: [[String: Any]] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind?(stmt!)
            while sqlite3_step(stmt!) == SQLITE_ROW {
                var row: [String: Any] = [:]
                let count = sqlite3_column_count(stmt!)
                for i in 0..<count {
                    let name = String(cString: sqlite3_column_name(stmt!, i))
                    let colType = sqlite3_column_type(stmt!, i)
                    switch colType {
                    case SQLITE_INTEGER:
                        row[name] = sqlite3_column_int64(stmt!, i)
                    case SQLITE_FLOAT:
                        row[name] = sqlite3_column_double(stmt!, i)
                    case SQLITE_TEXT:
                        row[name] = String(cString: sqlite3_column_text(stmt!, i))
                    case SQLITE_NULL:
                        row[name] = nil
                    default:
                        row[name] = nil
                    }
                }
                results.append(row)
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    private func executeUpdate(_ sql: String, bind: (OpaquePointer) -> Void) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt!)
            sqlite3_step(stmt!)
        }
        sqlite3_finalize(stmt)
    }
}
