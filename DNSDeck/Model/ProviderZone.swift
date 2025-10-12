//
//  ProviderZone.swift
//  DNSDeck
//
//  Created by ChatGPT on 12/10/25.
//

import Foundation

// Generic zone wrapper for different providers
enum ProviderZoneData: Hashable {
    case cloudflare(CFZone)
    case route53(R53HostedZone)
    
    var id: String {
        switch self {
        case .cloudflare(let zone): return zone.id
        case .route53(let zone): return zone.id
        }
    }
    
    var name: String {
        switch self {
        case .cloudflare(let zone): return zone.name
        case .route53(let zone): 
            // Remove trailing dot from Route 53 FQDN for display
            return zone.name.hasSuffix(".") ? String(zone.name.dropLast()) : zone.name
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
        self.zoneData = .cloudflare(zone)
    }
    
    init(provider: DNSProvider, zone: R53HostedZone) {
        self.provider = provider
        self.zoneData = .route53(zone)
    }
}

// Generic DNS record wrapper for different providers
enum ProviderRecordData: Hashable {
    case cloudflare(CFDNSRecord)
    case route53(R53ResourceRecordSet)
    
    var id: String {
        switch self {
        case .cloudflare(let record): return record.id
        case .route53(let record): return record.id
        }
    }
    
    var name: String {
        switch self {
        case .cloudflare(let record): return record.name
        case .route53(let record): return record.name
        }
    }
    
    var type: String {
        switch self {
        case .cloudflare(let record): return record.type
        case .route53(let record): return record.type
        }
    }
    
    var content: String {
        switch self {
        case .cloudflare(let record): return record.content
        case .route53(let record): 
            return record.resourceRecords?.first?.value ?? record.aliasTarget?.dnsName ?? ""
        }
    }
    
    var ttl: Int? {
        switch self {
        case .cloudflare(let record): return record.ttl
        case .route53(let record): return record.ttl
        }
    }
    
    var proxied: Bool? {
        switch self {
        case .cloudflare(let record): return record.proxied
        case .route53: return nil // Route 53 doesn't have proxy functionality
        }
    }
    
    var priority: Int? {
        switch self {
        case .cloudflare(let record): return record.priority
        case .route53: return nil // Route 53 doesn't store priority separately
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
        self.recordData = .cloudflare(record)
    }
    
    init(provider: DNSProvider, record: R53ResourceRecordSet) {
        self.provider = provider
        self.recordData = .route53(record)
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
        let r53Name: String
        if name == "@" {
            // Root domain
            r53Name = "\(zoneName)."
        } else if name.hasSuffix(".") {
            // Already fully qualified
            r53Name = name
        } else {
            // Subdomain - append zone name
            r53Name = "\(name).\(zoneName)."
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
        let r53Name: String?
        if let name = name {
            if name == "@" {
                // Root domain
                r53Name = "\(zoneName)."
            } else if name.hasSuffix(".") {
                // Already fully qualified
                r53Name = name
            } else {
                // Subdomain - append zone name
                r53Name = "\(name).\(zoneName)."
            }
        } else {
            r53Name = nil
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

