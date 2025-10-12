import Foundation

enum InputValidator {
    
    // MARK: - DNS Record Validation
    
    static func validateDNSName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("DNS name cannot be empty")
        }
        
        // Allow @ for root domain
        if trimmed == "@" {
            return .valid
        }
        
        // Check length (DNS labels max 63 chars, total max 253)
        if trimmed.count > 253 {
            return .invalid("DNS name too long (max 253 characters)")
        }
        
        // Basic DNS name validation
        let dnsNameRegex = "^[a-zA-Z0-9]([a-zA-Z0-9\\-_]*[a-zA-Z0-9])?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", dnsNameRegex)
        
        if !predicate.evaluate(with: trimmed) {
            return .invalid("Invalid DNS name format")
        }
        
        return .valid
    }
    
    static func validateIPv4Address(_ ip: String) -> ValidationResult {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("IP address cannot be empty")
        }
        
        let ipv4Regex = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", ipv4Regex)
        
        if !predicate.evaluate(with: trimmed) {
            return .invalid("Invalid IPv4 address format")
        }
        
        return .valid
    }
    
    static func validateIPv6Address(_ ip: String) -> ValidationResult {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("IP address cannot be empty")
        }
        
        // Basic IPv6 validation (simplified)
        let ipv6Regex = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", ipv6Regex)
        
        if predicate.evaluate(with: trimmed) {
            return .valid
        }
        
        // Try compressed format validation
        let compressedRegex = "^([0-9a-fA-F]{1,4}:)*::([0-9a-fA-F]{1,4}:)*[0-9a-fA-F]{1,4}$"
        let compressedPredicate = NSPredicate(format: "SELF MATCHES %@", compressedRegex)
        
        if !compressedPredicate.evaluate(with: trimmed) {
            return .invalid("Invalid IPv6 address format")
        }
        
        return .valid
    }
    
    static func validateTTL(_ ttl: Int) -> ValidationResult {
        guard ttl >= Constants.TTL.minimum && ttl <= Constants.TTL.maximum else {
            return .invalid("TTL must be between \(Constants.TTL.minimum) and \(Constants.TTL.maximum) seconds")
        }
        return .valid
    }
    
    static func validateMXPriority(_ priority: Int) -> ValidationResult {
        guard priority >= 0 && priority <= 65535 else {
            return .invalid("MX priority must be between 0 and 65535")
        }
        return .valid
    }
    
    static func validateSRVPort(_ port: Int) -> ValidationResult {
        guard port >= 1 && port <= 65535 else {
            return .invalid("Port must be between 1 and 65535")
        }
        return .valid
    }
    
    // MARK: - Credential Validation
    
    static func validateCloudflareToken(_ token: String) -> ValidationResult {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("API token cannot be empty")
        }
        
        // Cloudflare tokens are typically 40 characters long
        guard trimmed.count >= 20 else {
            return .invalid("API token appears to be too short")
        }
        
        // Basic format check (alphanumeric and some special chars)
        let tokenRegex = "^[a-zA-Z0-9_-]+$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", tokenRegex)
        
        if !predicate.evaluate(with: trimmed) {
            return .invalid("API token contains invalid characters")
        }
        
        return .valid
    }
    
    static func validateAWSAccessKey(_ accessKey: String) -> ValidationResult {
        let trimmed = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("Access key cannot be empty")
        }
        
        // AWS access keys start with AKIA and are 20 characters long
        guard trimmed.hasPrefix("AKIA") && trimmed.count == 20 else {
            return .invalid("Invalid AWS access key format")
        }
        
        let accessKeyRegex = "^AKIA[0-9A-Z]{16}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", accessKeyRegex)
        
        if !predicate.evaluate(with: trimmed) {
            return .invalid("Invalid AWS access key format")
        }
        
        return .valid
    }
    
    static func validateAWSSecretKey(_ secretKey: String) -> ValidationResult {
        let trimmed = secretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("Secret key cannot be empty")
        }
        
        // AWS secret keys are 40 characters long
        guard trimmed.count == 40 else {
            return .invalid("Invalid AWS secret key length")
        }
        
        return .valid
    }
}

enum ValidationResult {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let message): return message
        }
    }
}
