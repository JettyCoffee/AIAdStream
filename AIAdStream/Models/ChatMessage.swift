import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: MessageRole
    let content: String
    var toolCalls: [ToolCall]?
    var toolCallId: String?

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

// MARK: - Tool Call

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable {
    let name: String
    let arguments: String // JSON string
}

// MARK: - Tool Definition (sent to API)

struct ToolDef: Codable {
    let type: String
    let function: FunctionDef
}

struct FunctionDef: Codable {
    let name: String
    let description: String
    let parameters: JSONSchema
}

// MARK: - JSON Schema (simplified for tool parameters)

indirect enum JSONSchema: Codable {
    case object([String: JSONSchema], required: [String]? = nil)
    case string(description: String? = nil)
    case integer(description: String? = nil)
    case array(JSONSchema)

    enum CodingKeys: String, CodingKey {
        case type, description, properties, required, items
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let props, let required):
            try container.encode("object", forKey: .type)
            var propsDict: [String: JSONSchema] = [:]
            for (k, v) in props { propsDict[k] = v }
            try container.encode(propsDict, forKey: .properties)
            if let req = required { try container.encode(req, forKey: .required) }
        case .string(let desc):
            try container.encode("string", forKey: .type)
            if let d = desc { try container.encode(d, forKey: .description) }
        case .integer(let desc):
            try container.encode("integer", forKey: .type)
            if let d = desc { try container.encode(d, forKey: .description) }
        case .array(let items):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "object":
            let props = try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties) ?? [:]
            let req = try container.decodeIfPresent([String].self, forKey: .required)
            self = .object(props, required: req)
        case "string":
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .string(description: desc)
        case "integer":
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .integer(description: desc)
        case "array":
            let items = try container.decode(JSONSchema.self, forKey: .items)
            self = .array(items)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }
}

// MARK: - Stream Event
// MARK: - Stream Event

enum StreamEvent {
    case contentDelta(String)
    case toolCallStart(String)
    case toolCallResult(ToolResult)
    case done(String)
}

// MARK: - Tool Result (structured data for UI)

struct ToolResult {
    let toolName: String
    let ads: [AdItem]
    let detailAd: AdItem?
}

// MARK: - Conversation Item (ordered list for chat UI)

enum ConversationItem: Identifiable {
    case message(ChatMessage)
    case adCards([AdItem])

    var id: String {
        switch self {
        case .message(let msg): return msg.id
        case .adCards(let ads): return "ads_" + ads.map(\.id).joined(separator: "_")
        }
    }

    var message: ChatMessage? {
        if case .message(let msg) = self { return msg }
        return nil
    }

    var ads: [AdItem]? {
        if case .adCards(let list) = self { return list }
        return nil
    }
}

// MARK: - Conversation Record (persisted history)

struct ConversationRecord: Identifiable, Codable {
    var id: String
    var title: String
    var date: Date
    var items: [PersistedItem]
}

enum PersistedItem: Codable {
    case message(role: String, content: String)
    case adCards(adIds: [String])

    enum CodingKeys: String, CodingKey {
        case type, role, content, adIds
    }

    enum ItemType: String, Codable {
        case message, adCards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .message:
            let role = try container.decode(String.self, forKey: .role)
            let content = try container.decode(String.self, forKey: .content)
            self = .message(role: role, content: content)
        case .adCards:
            let adIds = try container.decode([String].self, forKey: .adIds)
            self = .adCards(adIds: adIds)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .message(let role, let content):
            try container.encode(ItemType.message, forKey: .type)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        case .adCards(let adIds):
            try container.encode(ItemType.adCards, forKey: .type)
            try container.encode(adIds, forKey: .adIds)
        }
    }
}
