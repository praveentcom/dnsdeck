

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
}

struct UpdateDNSRecordRequest: Encodable {
    var type: String?
    var name: String?
    var content: String?
    var ttl: Int?
    var proxied: Bool?
    var priority: Int?
    var data: RecordData?
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
