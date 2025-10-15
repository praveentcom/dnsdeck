import Foundation

enum AppError: Error, LocalizedError {
    case network(NetworkError)
    case keychain(KeychainError)
    case validation(ValidationError)
    case dns(DNSError)
    case csv(CSVError)
    case general(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case let .network(error):
            error.localizedDescription
        case let .keychain(error):
            error.localizedDescription
        case let .validation(error):
            error.localizedDescription
        case let .dns(error):
            error.localizedDescription
        case let .csv(error):
            error.localizedDescription
        case let .general(message):
            message
        case let .unknown(error):
            error.localizedDescription
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case noInternetConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            "No internet connection available"
        case .timeout:
            "Request timed out"
        case let .serverError(code):
            "Server error: \(code)"
        case .invalidResponse:
            "Invalid response from server"
        case .decodingFailed:
            "Failed to decode server response"
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            "Credential not found in keychain"
        case .duplicateItem:
            "Credential already exists"
        case .invalidData:
            "Invalid credential data"
        case .accessDenied:
            "Access denied to keychain"
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case invalidDomain(String)
    case invalidIPAddress(String)
    case invalidTTL(Int)
    case missingRequiredField(String)
    case invalidRecordType(String)

    var errorDescription: String? {
        switch self {
        case let .invalidDomain(domain):
            "Invalid domain: \(domain)"
        case let .invalidIPAddress(ip):
            "Invalid IP address: \(ip)"
        case let .invalidTTL(ttl):
            "Invalid TTL: \(ttl). Must be between 60 and 86400 seconds"
        case let .missingRequiredField(field):
            "Missing required field: \(field)"
        case let .invalidRecordType(type):
            "Invalid record type: \(type)"
        }
    }
}

enum DNSError: Error, LocalizedError {
    case recordNotFound
    case duplicateRecord
    case invalidRecordData
    case providerError(String)
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            "DNS record not found"
        case .duplicateRecord:
            "DNS record already exists"
        case .invalidRecordData:
            "Invalid DNS record data"
        case let .providerError(message):
            "Provider error: \(message)"
        case .quotaExceeded:
            "DNS record quota exceeded"
        }
    }
}

enum CSVError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat
    case emptyFile
    case missingHeaders([String])
    case invalidData(line: Int, message: String)
    case tooManyRecords(Int)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "CSV file not found"
        case .invalidFormat:
            "Invalid CSV file format"
        case .emptyFile:
            "CSV file is empty"
        case let .missingHeaders(headers):
            "Missing required CSV headers: \(headers.joined(separator: ", "))"
        case let .invalidData(line, message):
            "Invalid data on line \(line): \(message)"
        case let .tooManyRecords(count):
            "Too many records in CSV file (\(count)). Maximum allowed is 1000."
        }
    }
}
