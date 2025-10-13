
import Foundation

// Generic zone wrapper for different providers
enum ProviderZoneData: Hashable {
    case cloudflare(CFZone)
    case route53(R53HostedZone)

    var id: String {
        switch self {
        case let .cloudflare(zone): zone.id
        case let .route53(zone): zone.id
        }
    }

    var name: String {
        switch self {
        case let .cloudflare(zone): zone.name
        case let .route53(zone):
            // Remove trailing dot from Route 53 FQDN for display
            zone.name.hasSuffix(".") ? String(zone.name.dropLast()) : zone.name
        }
    }
}

struct ProviderZone: Identifiable, Hashable {
    let provider: DNSProvider
    let zoneData: ProviderZoneData

    var id: String { "\(provider.rawValue)|\(zoneData.id)" }
    var name: String { zoneData.name }

    // Convenience initializers
    init(provider: DNSProvider, zone: CFZone) {
        self.provider = provider
        zoneData = .cloudflare(zone)
    }

    init(provider: DNSProvider, zone: R53HostedZone) {
        self.provider = provider
        zoneData = .route53(zone)
    }
}

// Generic DNS record wrapper for different providers
enum ProviderRecordData: Hashable {
    case cloudflare(CFDNSRecord)
    case route53(R53ResourceRecordSet)

    var id: String {
        switch self {
        case let .cloudflare(record): record.id
        case let .route53(record): record.id
        }
    }

    var name: String {
        switch self {
        case let .cloudflare(record): record.name
        case let .route53(record): record.name
        }
    }

    var type: String {
        switch self {
        case let .cloudflare(record): record.type
        case let .route53(record): record.type
        }
    }

    var content: String {
        switch self {
        case let .cloudflare(record): record.content
        case let .route53(record):
            record.resourceRecords?.first?.value ?? record.aliasTarget?.dnsName ?? ""
        }
    }

    var ttl: Int? {
        switch self {
        case let .cloudflare(record): record.ttl
        case let .route53(record): record.ttl
        }
    }

    var proxied: Bool? {
        switch self {
        case let .cloudflare(record): record.proxied
        case .route53: nil // Route 53 doesn't have proxy functionality
        }
    }

    var priority: Int? {
        switch self {
        case let .cloudflare(record): record.priority
        case .route53: nil // Route 53 doesn't store priority separately
        }
    }
}

struct ProviderRecord: Identifiable, Hashable {
    let provider: DNSProvider
    let recordData: ProviderRecordData

    var id: String { "\(provider.rawValue)|\(recordData.id)" }
    var name: String { recordData.name }
    var type: String { recordData.type }
    var content: String { recordData.content }
    var ttl: Int? { recordData.ttl }
    var proxied: Bool? { recordData.proxied }
    var priority: Int? { recordData.priority }

    // Convenience initializers
    init(provider: DNSProvider, record: CFDNSRecord) {
        self.provider = provider
        recordData = .cloudflare(record)
    }

    init(provider: DNSProvider, record: R53ResourceRecordSet) {
        self.provider = provider
        recordData = .route53(record)
    }
}

// Generic record creation request
struct CreateProviderRecordRequest {
    let name: String
    let type: String
    let content: String
    let ttl: Int?
    let proxied: Bool? // Only for Cloudflare

    func toCloudflareRequest() -> CreateDNSRecordRequest {
        CreateDNSRecordRequest(
            type: type,
            name: name,
            content: content,
            ttl: ttl,
            proxied: proxied,
            priority: nil,
            data: nil
        )
    }

    func toRoute53Request() -> CreateR53RecordRequest {
        CreateR53RecordRequest(
            name: name,
            type: type,
            ttl: ttl,
            values: [content],
            weight: nil,
            setIdentifier: nil
        )
    }

    func toRoute53Request(zoneName: String) -> CreateR53RecordRequest {
        // Convert to fully qualified domain name for Route 53
        let r53Name: String = if name == "@" {
            // Root domain
            "\(zoneName)."
        } else if name.hasSuffix(".") {
            // Already fully qualified
            name
        } else {
            // Subdomain - append zone name
            "\(name).\(zoneName)."
        }

        return CreateR53RecordRequest(
            name: r53Name,
            type: type,
            ttl: ttl,
            values: [content],
            weight: nil,
            setIdentifier: nil
        )
    }
}

// Generic record update request
struct UpdateProviderRecordRequest {
    let name: String?
    let type: String?
    let content: String?
    let ttl: Int?
    let proxied: Bool? // Only for Cloudflare

    func toCloudflareRequest() -> UpdateDNSRecordRequest {
        UpdateDNSRecordRequest(
            type: type,
            name: name,
            content: content,
            ttl: ttl,
            proxied: proxied,
            priority: nil,
            data: nil
        )
    }

    func toRoute53Request(oldRecord: R53ResourceRecordSet, zoneName: String) -> UpdateR53RecordRequest {
        // Convert to fully qualified domain name for Route 53
        let r53Name: String? = if let name {
            if name == "@" {
                // Root domain
                "\(zoneName)."
            } else if name.hasSuffix(".") {
                // Already fully qualified
                name
            } else {
                // Subdomain - append zone name
                "\(name).\(zoneName)."
            }
        } else {
            nil
        }

        return UpdateR53RecordRequest(
            oldRecord: oldRecord,
            name: r53Name,
            type: type,
            ttl: ttl,
            values: content.map { [$0] },
            weight: nil,
            setIdentifier: nil
        )
    }

    func toRoute53Request(oldRecord: R53ResourceRecordSet) -> UpdateR53RecordRequest {
        UpdateR53RecordRequest(
            oldRecord: oldRecord,
            name: name,
            type: type,
            ttl: ttl,
            values: content.map { [$0] },
            weight: nil,
            setIdentifier: nil
        )
    }
}
