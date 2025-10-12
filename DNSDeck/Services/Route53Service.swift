import Foundation
import CryptoKit

// AWS-specific character sets for URL encoding
extension CharacterSet {
    static let awsQueryAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return allowed
    }()
    
    static let awsPathAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~/")
        return allowed
    }()
}

enum R53APIError: Error, LocalizedError {
    case missingCredentials
    case invalidCredentials
    case http(Int, String?)
    case aws(String)
    case decoding(Error)
    case encoding(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "AWS credentials are missing."
        case .invalidCredentials: return "AWS credentials are invalid."
        case .http(let code, let message): return "HTTP error \(code): \(message ?? "Unknown error")"
        case .aws(let message): return "AWS error: \(message)"
        case .decoding(let error): return "Decoding error: \(error.localizedDescription)"
        case .encoding(let error): return "Encoding error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from AWS."
        }
    }
}

final class Route53Service {
    private let baseURL = Constants.API.route53Base
    private let region = Constants.API.route53Region
    private let service = Constants.API.route53Service
    private let urlSession = NetworkConfiguration.urlSession
    
    private let credentialsProvider: () -> (accessKeyId: String?, secretAccessKey: String?)
    
    init(credentialsProvider: @escaping () -> (accessKeyId: String?, secretAccessKey: String?)) {
        self.credentialsProvider = credentialsProvider
    }
    
    // MARK: - Hosted Zones
    
    func listHostedZones() async throws -> [R53HostedZone] {
        var allZones: [R53HostedZone] = []
        var marker: String? = nil
        
        repeat {
            var components = URLComponents(string: "\(baseURL)/2013-04-01/hostedzone")!
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "maxitems", value: "\(Constants.Pagination.route53PageSize)")]
            if let marker = marker {
                queryItems.append(URLQueryItem(name: "marker", value: marker))
            }
            components.queryItems = queryItems
            
            let response: R53ListHostedZonesResponse = try await request(
                url: components.url!,
                method: "GET"
            )
            
            allZones.append(contentsOf: response.hostedZones)
            
            if response.isTruncated {
                marker = response.nextMarker
            } else {
                marker = nil
            }
        } while marker != nil
        
        return allZones
    }
    
    // MARK: - Resource Record Sets
    
    func listResourceRecordSets(hostedZoneId: String) async throws -> [R53ResourceRecordSet] {
        var allRecords: [R53ResourceRecordSet] = []
        var nextRecordName: String? = nil
        var nextRecordType: String? = nil
        var nextRecordIdentifier: String? = nil
        
        repeat {
            var components = URLComponents(string: "\(baseURL)/2013-04-01/hostedzone/\(cleanZoneId(hostedZoneId))/rrset")!
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "maxitems", value: "\(Constants.Pagination.route53MaxPageSize)")]
            
            if let name = nextRecordName {
                queryItems.append(URLQueryItem(name: "name", value: name))
            }
            if let type = nextRecordType {
                queryItems.append(URLQueryItem(name: "type", value: type))
            }
            if let identifier = nextRecordIdentifier {
                queryItems.append(URLQueryItem(name: "identifier", value: identifier))
            }
            
            components.queryItems = queryItems
            
            let response: R53ListResourceRecordSetsResponse = try await request(
                url: components.url!,
                method: "GET"
            )
            
            allRecords.append(contentsOf: response.resourceRecordSets)
            
            if response.isTruncated {
                nextRecordName = response.nextRecordName
                nextRecordType = response.nextRecordType
                nextRecordIdentifier = response.nextRecordIdentifier
            } else {
                nextRecordName = nil
                nextRecordType = nil
                nextRecordIdentifier = nil
            }
        } while nextRecordName != nil
        
        return allRecords
    }
    
    func createRecord(hostedZoneId: String, request recordRequest: CreateR53RecordRequest) async throws -> R53ChangeInfo {
        let change = R53Change(
            action: "CREATE",
            resourceRecordSet: recordRequest.toResourceRecordSet()
        )
        
        let changeBatch = R53ChangeBatch(
            comment: "Created via DNSDeck",
            changes: [change]
        )
        
        let changeRequest = R53ChangeResourceRecordSetsRequest(changeBatch: changeBatch)
        
        let response: R53ChangeResourceRecordSetsResponse = try await request(
            url: URL(string: "\(baseURL)/2013-04-01/hostedzone/\(cleanZoneId(hostedZoneId))/rrset")!,
            method: "POST",
            body: changeRequest
        )
        
        return response.changeInfo
    }
    
    func updateRecord(hostedZoneId: String, request recordRequest: UpdateR53RecordRequest) async throws -> R53ChangeInfo {
        let deleteChange = R53Change(
            action: "DELETE",
            resourceRecordSet: recordRequest.oldRecord
        )
        
        let createChange = R53Change(
            action: "CREATE",
            resourceRecordSet: recordRequest.toResourceRecordSet()
        )
        
        let changeBatch = R53ChangeBatch(
            comment: "Updated via DNSDeck",
            changes: [deleteChange, createChange]
        )
        
        let changeRequest = R53ChangeResourceRecordSetsRequest(changeBatch: changeBatch)
        
        let response: R53ChangeResourceRecordSetsResponse = try await request(
            url: URL(string: "\(baseURL)/2013-04-01/hostedzone/\(cleanZoneId(hostedZoneId))/rrset")!,
            method: "POST",
            body: changeRequest
        )
        
        return response.changeInfo
    }
    
    func deleteRecord(hostedZoneId: String, record: R53ResourceRecordSet) async throws -> R53ChangeInfo {
        let change = R53Change(
            action: "DELETE",
            resourceRecordSet: record
        )
        
        let changeBatch = R53ChangeBatch(
            comment: "Deleted via DNSDeck",
            changes: [change]
        )
        
        let changeRequest = R53ChangeResourceRecordSetsRequest(changeBatch: changeBatch)
        
        let response: R53ChangeResourceRecordSetsResponse = try await request(
            url: URL(string: "\(baseURL)/2013-04-01/hostedzone/\(cleanZoneId(hostedZoneId))/rrset")!,
            method: "POST",
            body: changeRequest
        )
        
        return response.changeInfo
    }
    
    // MARK: - Internal
    
    private func cleanZoneId(_ zoneId: String) -> String {
        // Remove /hostedzone/ prefix if present
        return zoneId.replacingOccurrences(of: "/hostedzone/", with: "")
    }
    
    private func request<T: Decodable>(url: URL, method: String, body: Encodable? = nil) async throws -> T {
        let credentials = credentialsProvider()
        
        guard let accessKeyId = credentials.accessKeyId?.trimmingCharacters(in: .whitespacesAndNewlines),
              let secretAccessKey = credentials.secretAccessKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessKeyId.isEmpty, !secretAccessKey.isEmpty else {
            throw R53APIError.missingCredentials
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        var bodyData: Data? = nil
        if let body = body {
            do {
                // Convert to XML for AWS API
                bodyData = try encodeToXML(body)
                request.httpBody = bodyData
                request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
            } catch {
                throw R53APIError.encoding(error)
            }
        }
        // Don't add extra headers - keep it minimal like AWS CLI
        
        // Sign the request using AWS Signature Version 4
        try signRequest(&request, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bodyData: bodyData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw R53APIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorMessage = extractErrorMessage(from: data)
            throw R53APIError.http(httpResponse.statusCode, errorMessage)
        }
        
        do {
            // Parse XML response
            return try decodeFromXML(T.self, from: data)
        } catch {
            throw R53APIError.decoding(error)
        }
    }
    
    private func signRequest(_ request: inout URLRequest, accessKeyId: String, secretAccessKey: String, bodyData: Data?) throws {
        let date = Date()
        
        // AWS expects basic ISO8601 format: YYYYMMDDTHHMMSSZ
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateString = dateFormatter.string(from: date)
        
        request.setValue(timestamp, forHTTPHeaderField: "X-Amz-Date")
        
        // Create canonical request and get signed headers
        let (canonicalRequest, signedHeaders) = createCanonicalRequestWithHeaders(request, bodyData: bodyData)
        
        // Create string to sign
        let credentialScope = "\(dateString)/\(region)/\(service)/aws4_request"
        let stringToSign = "AWS4-HMAC-SHA256\n\(timestamp)\n\(credentialScope)\n\(sha256Hash(canonicalRequest))"
        
        // Calculate signature
        let signature = calculateSignature(
            stringToSign: stringToSign,
            secretAccessKey: secretAccessKey,
            dateString: dateString,
            region: region,
            service: service
        )
        
        // Create authorization header with correct signed headers
        let authorization = "AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    
    private func createCanonicalRequestWithHeaders(_ request: URLRequest, bodyData: Data?) -> (String, String) {
        let (canonicalRequest, signedHeaders) = createCanonicalRequestInternal(request, bodyData: bodyData)
        return (canonicalRequest, signedHeaders)
    }
    
    private func createCanonicalRequest(_ request: URLRequest, bodyData: Data?) -> String {
        let (canonicalRequest, _) = createCanonicalRequestInternal(request, bodyData: bodyData)
        return canonicalRequest
    }
    
    private func createCanonicalRequestInternal(_ request: URLRequest, bodyData: Data?) -> (String, String) {
        let method = request.httpMethod ?? "GET"
        
        // Properly encode the URI path according to AWS spec
        let rawPath = request.url?.path ?? "/"
        let path = rawPath.addingPercentEncoding(withAllowedCharacters: .awsPathAllowed) ?? rawPath
        
        // Properly encode query string according to AWS spec
        let query: String
        if let queryString = request.url?.query, !queryString.isEmpty {
            // Parse and re-encode query parameters properly
            let queryItems = queryString.components(separatedBy: "&")
                .compactMap { item -> String? in
                    let parts = item.components(separatedBy: "=")
                    guard parts.count == 2 else { return nil }
                    let key = parts[0].addingPercentEncoding(withAllowedCharacters: .awsQueryAllowed) ?? parts[0]
                    let value = parts[1].addingPercentEncoding(withAllowedCharacters: .awsQueryAllowed) ?? parts[1]
                    return "\(key)=\(value)"
                }
                .sorted()
            query = queryItems.joined(separator: "&")
        } else {
            query = ""
        }
        
        // Create canonical headers - minimal approach like AWS CLI
        let host = request.url?.host ?? ""
        let amzDate = request.value(forHTTPHeaderField: "X-Amz-Date") ?? ""
        
        // Only sign the required headers: host and x-amz-date
        let headers = "host:\(host)\nx-amz-date:\(amzDate)"
        let signedHeaders = "host;x-amz-date"
        
        // Calculate payload hash
        let payloadHash = bodyData.map { sha256Hash($0) } ?? sha256Hash(Data())
        
        // Build canonical request according to AWS spec
        // Format: Method\nPath\nQueryString\nHeaders\n\nSignedHeaders\nPayloadHash
        let canonicalRequest = "\(method)\n\(path)\n\(query)\n\(headers)\n\n\(signedHeaders)\n\(payloadHash)"
        
        return (canonicalRequest, signedHeaders)
    }
    
    private func calculateSignature(stringToSign: String, secretAccessKey: String, dateString: String, region: String, service: String) -> String {
        // AWS Signature Version 4 key derivation
        // Step 1: Create the signing key through a series of HMAC operations
        let kSecret = "AWS4\(secretAccessKey)".data(using: .utf8)!
        let kDate = hmacSHA256(key: kSecret, data: dateString.data(using: .utf8)!)
        let kRegion = hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        
        // Step 2: Calculate the final signature
        let signature = hmacSHA256(key: kSigning, data: stringToSign.data(using: .utf8)!)
        return signature.map { String(format: "%02x", $0) }.joined()
    }
    
    
    private func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(authenticationCode)
    }
    
    private func sha256Hash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sha256Hash(_ string: String) -> String {
        sha256Hash(string.data(using: .utf8) ?? Data())
    }
    
    private func encodeToXML<T: Encodable>(_ object: T) throws -> Data {
        // Simple XML encoding for Route 53 API
        // This is a basic implementation - in production you might want to use a proper XML library
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(object)
        let json = try JSONSerialization.jsonObject(with: jsonData)
        
        let xmlString = convertJSONToXML(json, rootElement: "ChangeResourceRecordSetsRequest")
        return xmlString.data(using: .utf8) ?? Data()
    }
    
    private func decodeFromXML<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        // Simple XML to JSON conversion for Route 53 responses
        // This is a basic implementation - in production you might want to use a proper XML library
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw R53APIError.invalidResponse
        }
        
        let jsonData = try convertXMLToJSON(xmlString)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: jsonData)
    }
    
    private func convertJSONToXML(_ json: Any, rootElement: String) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<\(rootElement) xmlns=\"https://route53.amazonaws.com/doc/2013-04-01/\">\n"
        xml += convertJSONObjectToXML(json, indent: "  ")
        xml += "</\(rootElement)>\n"
        return xml
    }
    
    private func convertJSONObjectToXML(_ json: Any, indent: String = "") -> String {
        var xml = ""
        
        if let dict = json as? [String: Any] {
            for (key, value) in dict {
                if key == "changes" || key == "Changes" {
                    // Special handling for Changes array - each item should be wrapped in <Change>
                    if let array = value as? [Any] {
                        xml += "\(indent)<Changes>\n"
                        for item in array {
                            xml += "\(indent)  <Change>\n"
                            xml += convertJSONObjectToXML(item, indent: indent + "    ")
                            xml += "\(indent)  </Change>\n"
                        }
                        xml += "\(indent)</Changes>\n"
                    }
                } else if key == "resourceRecords" || key == "ResourceRecords" {
                    // Special handling for ResourceRecords array
                    if let array = value as? [Any] {
                        xml += "\(indent)<ResourceRecords>\n"
                        for item in array {
                            xml += "\(indent)  <ResourceRecord>\n"
                            xml += convertJSONObjectToXML(item, indent: indent + "    ")
                            xml += "\(indent)  </ResourceRecord>\n"
                        }
                        xml += "\(indent)</ResourceRecords>\n"
                    }
                } else if let array = value as? [Any] {
                    for item in array {
                        xml += "\(indent)<\(key)>\n"
                        xml += convertJSONObjectToXML(item, indent: indent + "  ")
                        xml += "\(indent)</\(key)>\n"
                    }
                } else if let nestedDict = value as? [String: Any] {
                    xml += "\(indent)<\(key)>\n"
                    xml += convertJSONObjectToXML(nestedDict, indent: indent + "  ")
                    xml += "\(indent)</\(key)>\n"
                } else {
                    xml += "\(indent)<\(key)>\(value)</\(key)>\n"
                }
            }
        }
        
        return xml
    }
    
    private func convertXMLToJSON(_ xml: String) throws -> Data {
        // Basic XML parsing - extract key information
        // This is a simplified parser for Route 53 responses
        var json: [String: Any] = [:]
        
        if xml.contains("<HostedZones>") {
            json = parseHostedZonesXML(xml)
        } else if xml.contains("<ResourceRecordSets>") {
            json = parseResourceRecordSetsXML(xml)
        } else if xml.contains("<ChangeInfo>") {
            json = parseChangeInfoXML(xml)
        }
        
        return try JSONSerialization.data(withJSONObject: json)
    }
    
    private func parseHostedZonesXML(_ xml: String) -> [String: Any] {
        // Simplified parsing - in production use proper XML parser
        var zones: [[String: Any]] = []
        
        let hostedZonePattern = #"<HostedZone>(.*?)</HostedZone>"#
        let regex = try! NSRegularExpression(pattern: hostedZonePattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: xml) {
                let zoneXML = String(xml[range])
                var zone: [String: Any] = [:]
                
                zone["Id"] = extractValue(from: zoneXML, tag: "Id")
                zone["Name"] = extractValue(from: zoneXML, tag: "Name")
                zone["CallerReference"] = extractValue(from: zoneXML, tag: "CallerReference")
                
                if let recordCount = extractValue(from: zoneXML, tag: "ResourceRecordSetCount"),
                   let count = Int(recordCount) {
                    zone["ResourceRecordSetCount"] = count
                }
                
                zones.append(zone)
            }
        }
        
        let isTruncated = extractValue(from: xml, tag: "IsTruncated") == "true"
        let maxItems = extractValue(from: xml, tag: "MaxItems") ?? "100"
        
        return [
            "HostedZones": zones,
            "IsTruncated": isTruncated,
            "MaxItems": maxItems
        ]
    }
    
    private func parseResourceRecordSetsXML(_ xml: String) -> [String: Any] {
        // Simplified parsing for resource record sets
        var recordSets: [[String: Any]] = []
        
        let recordSetPattern = #"<ResourceRecordSet>(.*?)</ResourceRecordSet>"#
        let regex = try! NSRegularExpression(pattern: recordSetPattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: xml) {
                let recordXML = String(xml[range])
                var record: [String: Any] = [:]
                
                record["Name"] = extractValue(from: recordXML, tag: "Name")
                record["Type"] = extractValue(from: recordXML, tag: "Type")
                
                if let ttlString = extractValue(from: recordXML, tag: "TTL"),
                   let ttl = Int(ttlString) {
                    record["TTL"] = ttl
                }
                
                // Extract resource records
                var resourceRecords: [[String: Any]] = []
                let resourceRecordPattern = #"<ResourceRecord>(.*?)</ResourceRecord>"#
                let rrRegex = try! NSRegularExpression(pattern: resourceRecordPattern, options: [.dotMatchesLineSeparators])
                let rrMatches = rrRegex.matches(in: recordXML, range: NSRange(recordXML.startIndex..., in: recordXML))
                
                for rrMatch in rrMatches {
                    if let rrRange = Range(rrMatch.range(at: 1), in: recordXML) {
                        let rrXML = String(recordXML[rrRange])
                        if let value = extractValue(from: rrXML, tag: "Value") {
                            resourceRecords.append(["Value": value])
                        }
                    }
                }
                
                if !resourceRecords.isEmpty {
                    record["ResourceRecords"] = resourceRecords
                }
                
                recordSets.append(record)
            }
        }
        
        return [
            "ResourceRecordSets": recordSets,
            "IsTruncated": extractValue(from: xml, tag: "IsTruncated") == "true",
            "MaxItems": extractValue(from: xml, tag: "MaxItems") ?? "300"
        ]
    }
    
    private func parseChangeInfoXML(_ xml: String) -> [String: Any] {
        return [
            "ChangeInfo": [
                "Id": extractValue(from: xml, tag: "Id") ?? "",
                "Status": extractValue(from: xml, tag: "Status") ?? "",
                "SubmittedAt": extractValue(from: xml, tag: "SubmittedAt") ?? "",
                "Comment": extractValue(from: xml, tag: "Comment")
            ]
        ]
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        // Try with and without namespace prefix
        let patterns = [
            "<\(tag)>(.*?)</\(tag)>",
            "<[^:]*:\(tag)>(.*?)</[^:]*:\(tag)>"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                continue
            }
            
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            if let match = matches.first,
               let range = Range(match.range(at: 1), in: xml) {
                let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        
        return nil
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        guard let xml = String(data: data, encoding: .utf8) else { return nil }
        return extractValue(from: xml, tag: "Message")
    }
}
