import Foundation
import os.log

enum Logger {
    private static let subsystem = Constants.bundleIdentifier
    
    static let network = os.Logger(subsystem: subsystem, category: "Network")
    static let keychain = os.Logger(subsystem: subsystem, category: "Keychain")
    static let ui = os.Logger(subsystem: subsystem, category: "UI")
    static let dns = os.Logger(subsystem: subsystem, category: "DNS")
    static let general = os.Logger(subsystem: subsystem, category: "General")
    
    // Convenience methods for common logging patterns
    static func logNetworkRequest(_ method: String, url: URL) {
        network.info("🌐 \(method) \(url.absoluteString)")
    }
    
    static func logNetworkResponse(_ statusCode: Int, url: URL) {
        if (200..<300).contains(statusCode) {
            network.info("✅ \(statusCode) \(url.absoluteString)")
        } else {
            network.error("❌ \(statusCode) \(url.absoluteString)")
        }
    }
    
    static func logNetworkError(_ error: Error, url: URL) {
        network.error("💥 Network error for \(url.absoluteString): \(error.localizedDescription)")
    }
    
    static func logKeychainOperation(_ operation: String, success: Bool) {
        if success {
            keychain.info("🔐 Keychain \(operation) succeeded")
        } else {
            keychain.error("🔐 Keychain \(operation) failed")
        }
    }
    
    static func logDNSOperation(_ operation: String, provider: String, recordType: String? = nil) {
        let typeInfo = recordType.map { " (\($0))" } ?? ""
        dns.info("🌍 \(operation) on \(provider)\(typeInfo)")
    }
    
    static func logError(_ error: Error, context: String) {
        general.error("💥 Error in \(context): \(error.localizedDescription)")
    }
}
