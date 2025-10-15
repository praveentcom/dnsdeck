

import Foundation

// Cloudflare Envelope
struct CFEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let result: T?
    let errors: [CFError]
    let messages: [CFMessage]?
    let result_info: CFResultInfo?
}

struct CFError: Decodable, Error {
    let code: Int
    let message: String
}

struct CFMessage: Decodable {
    let code: Int?
    let message: String?
}

struct CFResultInfo: Decodable {
    let page: Int?
    let per_page: Int?
    let total_pages: Int?
    let count: Int?
    let total_count: Int?
}

// Zones
struct CFZone: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: String?
}

// DNS Records
struct CFDNSRecord: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let content: String
    let ttl: Int?
    let proxied: Bool?
    let proxiable: Bool?
    let priority: Int?
    let tags: [String]?
    let data: RecordData?
    let created_on: Date?
    let modified_on: Date?
    let meta: CFRecordMeta?
    let comment: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, content, ttl, proxied, proxiable, priority, tags, data
        case created_on, modified_on, meta, comment
    }
    
    // Custom initializer to handle missing timestamp fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        content = try container.decode(String.self, forKey: .content)
        
        // Optional fields
        ttl = try container.decodeIfPresent(Int.self, forKey: .ttl)
        proxied = try container.decodeIfPresent(Bool.self, forKey: .proxied)
        proxiable = try container.decodeIfPresent(Bool.self, forKey: .proxiable)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        data = try container.decodeIfPresent(RecordData.self, forKey: .data)
        meta = try container.decodeIfPresent(CFRecordMeta.self, forKey: .meta)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        
        // Timestamp fields - handle Cloudflare's ISO8601 format with fractional seconds
        if let createdString = try? container.decodeIfPresent(String.self, forKey: .created_on) {
            created_on = parseCloudflareDate(createdString)
        } else {
            created_on = nil
        }
        
        if let modifiedString = try? container.decodeIfPresent(String.self, forKey: .modified_on) {
            modified_on = parseCloudflareDate(modifiedString)
        } else {
            modified_on = nil
        }
    }
}

// Create / Update payloads
struct CreateDNSRecordRequest: Encodable {
    var type: String
    var name: String
    var content: String?
    var ttl: Int? // 1 = automatic
    var proxied: Bool?
    var priority: Int?
    var data: RecordData?
    var comment: String?
}

struct UpdateDNSRecordRequest: Encodable {
    var type: String?
    var name: String?
    var content: String?
    var ttl: Int?
    var proxied: Bool?
    var priority: Int?
    var data: RecordData?
    var comment: String?
}

struct RecordData: Codable, Hashable {
    var service: String?
    var proto: String?
    var name: String?
    var priority: Int?
    var weight: Int?
    var port: Int?
    var target: String?
    var flags: Int?
    var tag: String?
    var value: String?
}

struct CFRecordMeta: Codable, Hashable {
    let auto_added: Bool?
    let managed_by_apps: Bool?
    let managed_by_argo_tunnel: Bool?
    let source: String?
}

// Helper function to parse Cloudflare's timestamp format
private func parseCloudflareDate(_ dateString: String) -> Date? {
    // Cloudflare uses ISO8601 with fractional seconds: "2025-10-15T18:55:44.157527Z"
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Fallback to standard ISO8601 without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}
