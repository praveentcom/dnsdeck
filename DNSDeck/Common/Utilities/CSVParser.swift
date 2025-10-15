import Foundation

struct CSVRecord {
    let type: String
    let name: String
    let value: String
    let ttl: Int?
    let priority: Int?
    let proxied: Bool?
    let comment: String?
    
    init(type: String, name: String, value: String, ttl: Int? = nil, priority: Int? = nil, proxied: Bool? = nil, comment: String? = nil) {
        self.type = type.uppercased()
        self.name = name
        self.value = value
        self.ttl = ttl
        self.priority = priority
        self.proxied = proxied
        self.comment = comment
    }
}

struct CSVParseResult {
    let records: [CSVRecord]
    let errors: [CSVParseError]
    let totalLines: Int
    
    var isValid: Bool {
        return errors.isEmpty && !records.isEmpty
    }
    
    var hasWarnings: Bool {
        return !errors.filter { $0.severity == .warning }.isEmpty
    }
}

struct CSVParseError: Error, Identifiable {
    let id = UUID()
    let line: Int
    let message: String
    let severity: Severity
    
    enum Severity {
        case error
        case warning
    }
}

class CSVParser {
    static func parse(from url: URL) throws -> CSVParseResult {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content: content)
    }
    
    static func parse(content: String) -> CSVParseResult {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            return CSVParseResult(
                records: [],
                errors: [CSVParseError(line: 0, message: "CSV file is empty", severity: .error)],
                totalLines: 0
            )
        }
        
        var records: [CSVRecord] = []
        var errors: [CSVParseError] = []
        
        // Parse header
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine).map { $0.lowercased() }
        
        // Validate required headers
        let requiredHeaders = ["type", "name", "value"]
        let missingHeaders = requiredHeaders.filter { !headers.contains($0) }
        
        if !missingHeaders.isEmpty {
            errors.append(CSVParseError(
                line: 1,
                message: "Missing required headers: \(missingHeaders.joined(separator: ", "))",
                severity: .error
            ))
            return CSVParseResult(records: [], errors: errors, totalLines: lines.count)
        }
        
        // Find column indices
        guard let typeIndex = headers.firstIndex(of: "type"),
              let nameIndex = headers.firstIndex(of: "name"),
              let valueIndex = headers.firstIndex(of: "value") else {
            errors.append(CSVParseError(
                line: 1,
                message: "Could not locate required columns",
                severity: .error
            ))
            return CSVParseResult(records: [], errors: errors, totalLines: lines.count)
        }
        
        let ttlIndex = headers.firstIndex(of: "ttl")
        let priorityIndex = headers.firstIndex(of: "priority")
        let proxiedIndex = headers.firstIndex(of: "proxied")
        let commentIndex = headers.firstIndex(of: "comment")
        
        // Parse data rows
        for (index, line) in lines.dropFirst().enumerated() {
            let lineNumber = index + 2 // +2 because we dropped first and arrays are 0-indexed
            let fields = parseCSVLine(line)
            
            // Validate field count
            if fields.count < headers.count {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: "Insufficient fields in row (expected \(headers.count), got \(fields.count))",
                    severity: .error
                ))
                continue
            }
            
            // Extract required fields
            let type = fields[typeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let name = fields[nameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = fields[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate required fields
            if type.isEmpty {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: "Type field is empty",
                    severity: .error
                ))
                continue
            }
            
            if name.isEmpty {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: "Name field is empty",
                    severity: .error
                ))
                continue
            }
            
            if value.isEmpty {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: "Value field is empty",
                    severity: .error
                ))
                continue
            }
            
            // Validate DNS record type
            let validTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "CAA", "PTR"]
            if !validTypes.contains(type.uppercased()) {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: "Invalid DNS record type: \(type)",
                    severity: .warning
                ))
            }
            
            // Validate record content based on type
            if let validationError = validateRecordContent(type: type.uppercased(), content: value, name: name) {
                errors.append(CSVParseError(
                    line: lineNumber,
                    message: validationError,
                    severity: .warning
                ))
            }
            
            // Parse optional fields
            var ttl: Int?
            if let ttlIndex = ttlIndex, ttlIndex < fields.count {
                let ttlString = fields[ttlIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !ttlString.isEmpty {
                    if let parsedTTL = Int(ttlString), parsedTTL > 0 {
                        ttl = parsedTTL
                    } else {
                        errors.append(CSVParseError(
                            line: lineNumber,
                            message: "Invalid TTL value: \(ttlString)",
                            severity: .warning
                        ))
                    }
                }
            }
            
            var priority: Int?
            if let priorityIndex = priorityIndex, priorityIndex < fields.count {
                let priorityString = fields[priorityIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !priorityString.isEmpty {
                    if let parsedPriority = Int(priorityString), parsedPriority >= 0 {
                        priority = parsedPriority
                    } else {
                        errors.append(CSVParseError(
                            line: lineNumber,
                            message: "Invalid priority value: \(priorityString)",
                            severity: .warning
                        ))
                    }
                }
            }
            
            var proxied: Bool?
            if let proxiedIndex = proxiedIndex, proxiedIndex < fields.count {
                let proxiedString = fields[proxiedIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !proxiedString.isEmpty {
                    switch proxiedString.lowercased() {
                    case "true", "1", "yes", "on":
                        proxied = true
                    case "false", "0", "no", "off":
                        proxied = false
                    default:
                        errors.append(CSVParseError(
                            line: lineNumber,
                            message: "Invalid proxied value: \(proxiedString) (use true/false)",
                            severity: .warning
                        ))
                    }
                }
            }
            
            var comment: String?
            if let commentIndex = commentIndex, commentIndex < fields.count {
                let commentString = fields[commentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !commentString.isEmpty {
                    comment = commentString
                }
            }
            
            // Handle special cases for record types
            var finalValue = value
            var finalPriority = priority
            
            // Handle MX records with priority in the value field
            if type.uppercased() == "MX" && priority == nil {
                let parts = value.split(separator: " ", maxSplits: 1)
                if parts.count == 2, let extractedPriority = Int(parts[0]) {
                    finalPriority = extractedPriority
                    finalValue = String(parts[1])
                }
            }
            
            // Handle TXT records - ensure they're quoted
            if type.uppercased() == "TXT" {
                if !finalValue.hasPrefix("\"") || !finalValue.hasSuffix("\"") {
                    finalValue = "\"\(finalValue)\""
                }
            }
            
            // Create record
            let record = CSVRecord(
                type: type,
                name: name,
                value: finalValue,
                ttl: ttl,
                priority: finalPriority,
                proxied: proxied,
                comment: comment
            )
            
            records.append(record)
        }
        
        // Check for too many records (limit to 1000 for safety)
        if records.count > 1000 {
            errors.append(CSVParseError(
                line: 0,
                message: "Too many records (\(records.count)). Maximum allowed is 1000.",
                severity: .error
            ))
        }
        
        return CSVParseResult(records: records, errors: errors, totalLines: lines.count)
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes {
                    // Check if this is an escaped quote
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField += "\""
                        i = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        fields.append(currentField)
        return fields
    }
    
    private static func validateRecordContent(type: String, content: String, name: String) -> String? {
        switch type {
        case "A":
            if !isValidIPv4(content) {
                return "Invalid IPv4 address: \(content)"
            }
        case "AAAA":
            if !isValidIPv6(content) {
                return "Invalid IPv6 address: \(content)"
            }
        case "CNAME", "NS":
            if !isValidDomain(content) {
                return "Invalid domain name: \(content)"
            }
        case "MX":
            // MX records can have format "priority domain" or just "domain"
            let parts = content.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                if Int(parts[0]) == nil {
                    return "Invalid MX priority: \(parts[0])"
                }
                if !isValidDomain(String(parts[1])) {
                    return "Invalid MX domain: \(parts[1])"
                }
            } else if parts.count == 1 {
                if !isValidDomain(String(parts[0])) {
                    return "Invalid MX domain: \(parts[0])"
                }
            } else {
                return "Invalid MX record format. Expected 'priority domain' or 'domain'"
            }
        case "TXT":
            // TXT records can contain almost anything, but check for reasonable length
            if content.count > 255 {
                return "TXT record too long (max 255 characters)"
            }
        case "SRV":
            // SRV records should have format "priority weight port target"
            let parts = content.split(separator: " ")
            if parts.count != 4 {
                return "Invalid SRV record format. Expected 'priority weight port target'"
            }
            if Int(parts[0]) == nil {
                return "Invalid SRV priority: \(parts[0])"
            }
            if Int(parts[1]) == nil {
                return "Invalid SRV weight: \(parts[1])"
            }
            if Int(parts[2]) == nil {
                return "Invalid SRV port: \(parts[2])"
            }
            if !isValidDomain(String(parts[3])) {
                return "Invalid SRV target: \(parts[3])"
            }
        default:
            break
        }
        
        return nil
    }
    
    private static func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        
        for part in parts {
            guard let num = Int(part), num >= 0, num <= 255 else {
                return false
            }
        }
        return true
    }
    
    private static func isValidIPv6(_ ip: String) -> Bool {
        // Basic IPv6 validation - could be more comprehensive
        let parts = ip.split(separator: ":")
        guard parts.count <= 8 else { return false }
        
        for part in parts {
            if part.isEmpty { continue } // Allow :: notation
            guard part.count <= 4 else { return false }
            for char in part {
                guard char.isHexDigit else { return false }
            }
        }
        return true
    }
    
    private static func isValidDomain(_ domain: String) -> Bool {
        // Basic domain validation
        guard !domain.isEmpty, domain.count <= 253 else { return false }
        
        let labels = domain.split(separator: ".")
        guard !labels.isEmpty else { return false }
        
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard label.first?.isLetter == true || label.first?.isNumber == true else { return false }
            guard label.last?.isLetter == true || label.last?.isNumber == true else { return false }
            
            for char in label {
                guard char.isLetter || char.isNumber || char == "-" else { return false }
            }
        }
        
        return true
    }
}

// Extension to convert CSVRecord to CreateProviderRecordRequest
extension CSVRecord {
    func toCreateProviderRecordRequest() -> CreateProviderRecordRequest {
        return CreateProviderRecordRequest(
            name: name,
            type: type,
            content: value,
            ttl: ttl,
            proxied: proxied,
            priority: priority,
            comment: comment
        )
    }
}
