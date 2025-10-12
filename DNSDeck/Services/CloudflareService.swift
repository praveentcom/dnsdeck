

import Foundation

enum CFAPIError: Error, LocalizedError {
    case missingToken
    case http(Int)
    case cloudflare([CFError])
    case decoding(Error)
    var errorDescription: String? {
        switch self {
        case .missingToken: return "Cloudflare API token is missing."
        case .http(let code): return "HTTP error \(code)."
        case .cloudflare(let errs): return errs.map(\.message).joined(separator: "\n")
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}

final class CloudflareService {
    private let base = URL(string: Constants.API.cloudflareBase)!
    private let tokenProvider: () -> String?
    private let urlSession = NetworkConfiguration.urlSession

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }

    // MARK: - Zones

    func listZones(nameFilter: String? = nil) async throws -> [CFZone] {
        var all: [CFZone] = []
        var page = 1
        repeat {
            var comps = URLComponents(url: base.appendingPathComponent("zones"), resolvingAgainstBaseURL: false)!
            var q: [URLQueryItem] = [URLQueryItem(name: "per_page", value: "\(Constants.Pagination.cloudflarePageSize)"),
                                     URLQueryItem(name: "page", value: "\(page)")]
            if let name = nameFilter, !name.isEmpty {
                q.append(URLQueryItem(name: "name", value: name))
            }
            comps.queryItems = q
            let env: CFEnvelope<[CFZone]> = try await request(url: comps.url!, method: "GET")
            if let result = env.result { all += result }
            let next = (env.result_info?.page ?? page) < (env.result_info?.total_pages ?? page)
            if next { page += 1 } else { break }
        } while true
        return all
    }

    // MARK: - Records

    func listRecords(zoneId: String) async throws -> [CFDNSRecord] {
        var all: [CFDNSRecord] = []
        var page = 1
        repeat {
            var comps = URLComponents(url: base.appendingPathComponent("zones/\(zoneId)/dns_records"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "per_page", value: "\(Constants.Pagination.cloudflareMaxPageSize)"),
                                URLQueryItem(name: "page", value: "\(page)")]
            let env: CFEnvelope<[CFDNSRecord]> = try await request(url: comps.url!, method: "GET")
            if let result = env.result { all += result }
            let next = (env.result_info?.page ?? page) < (env.result_info?.total_pages ?? page)
            if next { page += 1 } else { break }
        } while true
        return all
    }

    func createRecord(zoneId: String, payload: CreateDNSRecordRequest) async throws -> CFDNSRecord {
        let url = base.appendingPathComponent("zones/\(zoneId)/dns_records")
        let env: CFEnvelope<CFDNSRecord> = try await request(url: url, method: "POST", body: payload)
        guard let record = env.result else { throw CFAPIError.cloudflare(env.errors) }
        return record
    }

    func updateRecord(zoneId: String, recordId: String, payload: UpdateDNSRecordRequest) async throws -> CFDNSRecord {
        let url = base.appendingPathComponent("zones/\(zoneId)/dns_records/\(recordId)")
        let env: CFEnvelope<CFDNSRecord> = try await request(url: url, method: "PATCH", body: payload)
        guard let record = env.result else { throw CFAPIError.cloudflare(env.errors) }
        return record
    }

    func deleteRecord(zoneId: String, recordId: String) async throws {
        let url = base.appendingPathComponent("zones/\(zoneId)/dns_records/\(recordId)")
        let env: CFEnvelope<[String: String]> = try await request(url: url, method: "DELETE")
        if !(env.success) { throw CFAPIError.cloudflare(env.errors) }
    }

    // MARK: - Internal

    private func request<T: Decodable>(url: URL, method: String, body: Encodable? = nil) async throws -> T {
        guard let token = tokenProvider() else { throw CFAPIError.missingToken }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CFAPIError.http(-1) }
        guard (200..<300).contains(http.statusCode) else {
            // Cloudflare still wraps errors in JSON; try decode for better message.
            if let env = try? JSONDecoder().decode(CFEnvelope<[String: String]>.self, from: data), !env.success {
                throw CFAPIError.cloudflare(env.errors)
            }
            throw CFAPIError.http(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CFAPIError.decoding(error)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self._encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
