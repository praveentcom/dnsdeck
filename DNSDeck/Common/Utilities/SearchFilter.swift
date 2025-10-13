import Foundation

enum SearchFilter {
    static func filterRecords(_ records: [ProviderRecord], searchText: String) -> [ProviderRecord] {
        guard !searchText.isEmpty else { return records }

        let query = searchText.lowercased()

        return records.filter { record in
            record.name.lowercased().contains(query) ||
                record.type.lowercased().contains(query) ||
                recordContentText(for: record).lowercased().contains(query)
        }
    }

    private static func recordContentText(for record: ProviderRecord) -> String {
        // This should match the logic in RecordsView
        switch record.type {
        case "SRV":
            if case let .cloudflare(cfRecord) = record.recordData,
               let data = cfRecord.data
            {
                return "\(data.priority ?? 0) \(data.weight ?? 0) \(data.port ?? 0) \(data.target ?? "")"
            }
            return record.content
        case "CAA":
            if case let .cloudflare(cfRecord) = record.recordData,
               let data = cfRecord.data
            {
                return "\(data.flags ?? 0) \(data.tag ?? "") \(data.value ?? "")"
            }
            return record.content
        default:
            return record.content
        }
    }
}
