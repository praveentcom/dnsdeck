//
//  Route53Models.swift
//  DNSDeck
//
//  Created by ChatGPT on 12/10/25.
//

import Foundation

// MARK: - AWS Route 53 API Models

// Route 53 Hosted Zone
struct R53HostedZone: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let callerReference: String?
    let config: R53HostedZoneConfig?
    let resourceRecordSetCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case callerReference = "CallerReference"
        case config = "Config"
        case resourceRecordSetCount = "ResourceRecordSetCount"
    }
}

struct R53HostedZoneConfig: Codable, Hashable {
    let privateZone: Bool?
    let comment: String?
    
    enum CodingKeys: String, CodingKey {
        case privateZone = "PrivateZone"
        case comment = "Comment"
    }
}

// Route 53 Resource Record Set
struct R53ResourceRecordSet: Codable, Identifiable, Hashable {
    let name: String
    let type: String
    let ttl: Int?
    let resourceRecords: [R53ResourceRecord]?
    let aliasTarget: R53AliasTarget?
    let weight: Int?
    let region: String?
    let geoLocation: R53GeoLocation?
    let failover: String?
    let multiValueAnswer: Bool?
    let setIdentifier: String?
    let healthCheckId: String?
    
    var id: String {
        // Create a unique identifier combining name, type, and setIdentifier
        let identifier = setIdentifier ?? ""
        return "\(name)|\(type)|\(identifier)"
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case type = "Type"
        case ttl = "TTL"
        case resourceRecords = "ResourceRecords"
        case aliasTarget = "AliasTarget"
        case weight = "Weight"
        case region = "Region"
        case geoLocation = "GeoLocation"
        case failover = "Failover"
        case multiValueAnswer = "MultiValueAnswer"
        case setIdentifier = "SetIdentifier"
        case healthCheckId = "HealthCheckId"
    }
}

struct R53ResourceRecord: Codable, Hashable {
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case value = "Value"
    }
}

struct R53AliasTarget: Codable, Hashable {
    let dnsName: String
    let hostedZoneId: String
    let evaluateTargetHealth: Bool
    
    enum CodingKeys: String, CodingKey {
        case dnsName = "DNSName"
        case hostedZoneId = "HostedZoneId"
        case evaluateTargetHealth = "EvaluateTargetHealth"
    }
}

struct R53GeoLocation: Codable, Hashable {
    let continentCode: String?
    let countryCode: String?
    let subdivisionCode: String?
    
    enum CodingKeys: String, CodingKey {
        case continentCode = "ContinentCode"
        case countryCode = "CountryCode"
        case subdivisionCode = "SubdivisionCode"
    }
}

// Request/Response wrappers
struct R53ListHostedZonesResponse: Codable {
    let hostedZones: [R53HostedZone]
    let marker: String?
    let isTruncated: Bool
    let nextMarker: String?
    let maxItems: String
    
    enum CodingKeys: String, CodingKey {
        case hostedZones = "HostedZones"
        case marker = "Marker"
        case isTruncated = "IsTruncated"
        case nextMarker = "NextMarker"
        case maxItems = "MaxItems"
    }
}

struct R53ListResourceRecordSetsResponse: Codable {
    let resourceRecordSets: [R53ResourceRecordSet]
    let isTruncated: Bool
    let nextRecordName: String?
    let nextRecordType: String?
    let nextRecordIdentifier: String?
    let maxItems: String
    
    enum CodingKeys: String, CodingKey {
        case resourceRecordSets = "ResourceRecordSets"
        case isTruncated = "IsTruncated"
        case nextRecordName = "NextRecordName"
        case nextRecordType = "NextRecordType"
        case nextRecordIdentifier = "NextRecordIdentifier"
        case maxItems = "MaxItems"
    }
}

// Change batch for creating/updating/deleting records
struct R53ChangeBatch: Codable {
    let comment: String?
    let changes: [R53Change]
    
    enum CodingKeys: String, CodingKey {
        case comment = "Comment"
        case changes = "Changes"
    }
}

struct R53Change: Codable {
    let action: String // "CREATE", "DELETE", "UPSERT"
    let resourceRecordSet: R53ResourceRecordSet
    
    enum CodingKeys: String, CodingKey {
        case action = "Action"
        case resourceRecordSet = "ResourceRecordSet"
    }
}

struct R53ChangeResourceRecordSetsRequest: Codable {
    let changeBatch: R53ChangeBatch
    
    enum CodingKeys: String, CodingKey {
        case changeBatch = "ChangeBatch"
    }
}

struct R53ChangeResourceRecordSetsResponse: Codable {
    let changeInfo: R53ChangeInfo
    
    enum CodingKeys: String, CodingKey {
        case changeInfo = "ChangeInfo"
    }
}

struct R53ChangeInfo: Codable {
    let id: String
    let status: String
    let submittedAt: String
    let comment: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case status = "Status"
        case submittedAt = "SubmittedAt"
        case comment = "Comment"
    }
}

// Convenience structures for creating records
struct CreateR53RecordRequest {
    let name: String
    let type: String
    let ttl: Int?
    let values: [String]
    let weight: Int?
    let setIdentifier: String?
    
    func toResourceRecordSet() -> R53ResourceRecordSet {
        R53ResourceRecordSet(
            name: name,
            type: type,
            ttl: ttl,
            resourceRecords: values.map { R53ResourceRecord(value: $0) },
            aliasTarget: nil,
            weight: weight,
            region: nil,
            geoLocation: nil,
            failover: nil,
            multiValueAnswer: nil,
            setIdentifier: setIdentifier,
            healthCheckId: nil
        )
    }
}

struct UpdateR53RecordRequest {
    let oldRecord: R53ResourceRecordSet
    let name: String?
    let type: String?
    let ttl: Int?
    let values: [String]?
    let weight: Int?
    let setIdentifier: String?
    
    func toResourceRecordSet() -> R53ResourceRecordSet {
        R53ResourceRecordSet(
            name: name ?? oldRecord.name,
            type: type ?? oldRecord.type,
            ttl: ttl ?? oldRecord.ttl,
            resourceRecords: values?.map { R53ResourceRecord(value: $0) } ?? oldRecord.resourceRecords,
            aliasTarget: oldRecord.aliasTarget,
            weight: weight ?? oldRecord.weight,
            region: oldRecord.region,
            geoLocation: oldRecord.geoLocation,
            failover: oldRecord.failover,
            multiValueAnswer: oldRecord.multiValueAnswer,
            setIdentifier: setIdentifier ?? oldRecord.setIdentifier,
            healthCheckId: oldRecord.healthCheckId
        )
    }
}
