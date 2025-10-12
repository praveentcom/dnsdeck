import Foundation

enum Constants {
    // App Configuration
    static let bundleIdentifier = "dev.dnsdeck.DNSDeck"
    static let keychainService = "dev.dnsdeck.DNSDeck"
    
    // Network Configuration
    static let requestTimeout: TimeInterval = 30.0
    static let resourceTimeout: TimeInterval = 60.0
    static let maxConnectionsPerHost = 4
    
    // API Endpoints
    enum API {
        static let cloudflareBase = "https://api.cloudflare.com/client/v4"
        static let route53Base = "https://route53.amazonaws.com"
        static let route53Region = "us-east-1"
        static let route53Service = "route53"
    }
    
    // Pagination
    enum Pagination {
        static let cloudflarePageSize = 50
        static let cloudflareMaxPageSize = 100
        static let route53PageSize = 100
        static let route53MaxPageSize = 300
    }
    
    // DNS Record Types
    enum DNSRecordTypes {
        static let proxyableTypes = ["A", "AAAA", "CNAME"]
        static let supportedTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "PTR", "CAA", "NS"]
    }
    
    // TTL Values
    enum TTL {
        static let automatic = 1
        static let minimum = 60
        static let maximum = 86400
        static let `default` = 300
    }
    
    // UI Constants
    enum UI {
        static let minimumWindowWidth: CGFloat = 800
        static let minimumWindowHeight: CGFloat = 800
        static let preferencesWindowWidth: CGFloat = 640
        static let preferencesWindowHeight: CGFloat = 480
        static let tableColumnMinWidth: CGFloat = 160
        static let contentColumnMinWidth: CGFloat = 240
    }
    
    // Support
    enum Support {
        static let email = "support@dnsdeck.dev"
        static let website = "https://dnsdeck.dev"
    }
}
