

import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: AppModel
    let zone: ProviderZone

    @State private var showAdd = false
    @State private var showEdit = false
    @State private var isSubmitting = false
    @StateObject private var debouncedSearch = DebouncedSearch()
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteIDs: [String] = []
    @State private var selectedRecord: ProviderRecord?

    var filteredRecords: [ProviderRecord] {
        SearchFilter.filterRecords(model.records, searchText: debouncedSearch.debouncedSearchText)
    }

    private var noRecordsView: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: debouncedSearch.debouncedSearchText.isEmpty ? "No Records Found" : "No Matching Records",
            message: debouncedSearch.debouncedSearchText.isEmpty ?
                "This zone doesn't have any DNS records yet." :
                "No records match your search criteria.",
            actionTitle: debouncedSearch.debouncedSearchText.isEmpty ? "Add Record" : nil,
            action: debouncedSearch.debouncedSearchText.isEmpty ? { showAdd = true } : nil
        )
        .disabled(isSubmitting)
    }

    private var recordsTable: some View {
        #if os(macOS)
        Table(filteredRecords) {
            TableColumn("Type") { (record: ProviderRecord) in
                TypeBadge(type: record.type)
            }

            TableColumn("Name") { (record: ProviderRecord) in
                Text(record.name).textSelection(.enabled)
            }
            .width(min: Constants.UI.tableColumnMinWidth)

            TableColumn("Content") { (record: ProviderRecord) in
                Text(recordContentText(for: record))
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            .width(min: Constants.UI.contentColumnMinWidth)

            TableColumn("TTL") { (record: ProviderRecord) in
                Text(ttlText(record.ttl))
            }

            TableColumn("Proxy Status") { (record: ProviderRecord) in
                if let proxied = record.proxied {
                    CloudflareProxyIcon(isProxied: proxied)
                }
            }

            TableColumn("Priority") { (record: ProviderRecord) in
                if let priority = record.priority {
                    PriorityBadge(priority: record.priority)
                }
            }
        }
        .contextMenu(forSelectionType: ProviderRecord.ID.self) { items in
            if let recordId = items.first,
               let record = model.records.first(where: { $0.id == recordId })
            {
                Button("Edit") {
                    selectedRecord = record
                    showEdit = true
                }
                .disabled(isSubmitting)

                Divider()

                Button("Delete", role: .destructive) {
                    pendingDeleteIDs = [recordId]
                    showDeleteConfirmation = true
                }
                .disabled(isSubmitting)
            }
        }
        #else
        recordsList
        #endif
    }

    #if os(iOS)
    private var recordsList: some View {
        List(filteredRecords) { record in
            RecordRowView(record: record)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        pendingDeleteIDs = [record.id]
                        showDeleteConfirmation = true
                    }
                    .disabled(isSubmitting)

                    Button("Edit") {
                        selectedRecord = record
                        showEdit = true
                    }
                    .disabled(isSubmitting)
                    .tint(.accent)
                }
                .contextMenu {
                    Button("Edit") {
                        selectedRecord = record
                        showEdit = true
                    }
                    .disabled(isSubmitting)

                    Divider()

                    Button("Delete", role: .destructive) {
                        pendingDeleteIDs = [record.id]
                        showDeleteConfirmation = true
                    }
                    .disabled(isSubmitting)
                }
        }
        .listStyle(.plain)
    }
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if filteredRecords.isEmpty, !model.isLoading {
                noRecordsView
            } else {
                recordsTable
                    .loadingOverlay(text: "Loading records…", isVisible: model.isLoading)
            }
        }
        .searchable(text: $debouncedSearch.searchText)
        .navigationTitle(zone.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add record", systemImage: "plus")
                    }
                }
                .disabled(isSubmitting)

                Button {
                    Task { await model.refreshRecords(for: zone) }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecordSheet(zone: zone, isSubmitting: $isSubmitting)
                .environmentObject(model)
            #if os(macOS)
                .frame(width: 520)
            #endif
        }
        .sheet(isPresented: $showEdit) {
            if let record = selectedRecord {
                EditRecordSheet(zone: zone, record: record, isSubmitting: $isSubmitting)
                    .environmentObject(model)
                #if os(macOS)
                    .frame(width: 520)
                #endif
            }
        }
        .alert("Delete Records?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeleteIDs
                pendingDeleteIDs = []
                Task {
                    await deleteRecordsWithErrorHandling(ids: ids)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteIDs = []
            }
        } message: {
            let count = pendingDeleteIDs.count
            Text("\(count) record\(count == 1 ? "" : "s") will be deleted and cannot be reversed.")
        }
        .withErrorHandling(model.errorHandler)
    }

    private func recordContentText(for record: ProviderRecord) -> String {
        // For SRV records, try to extract structured data if available
        if record.type.uppercased() == "SRV" {
            switch record.recordData {
            case let .cloudflare(cfRecord):
                if let data = cfRecord.data {
                    let priority = data.priority.map(String.init) ?? "-"
                    let weight = data.weight.map(String.init) ?? "-"
                    let port = data.port.map(String.init) ?? "-"
                    let target = (data.target ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = [priority, weight, port, target.isEmpty ? "-" : target]
                    return parts.joined(separator: " ")
                }
            case .route53:
                // Route 53 SRV records are stored as plain text content
                break
            }
        }
        return record.content
    }

    private func ttlText(_ ttl: Int?) -> String {
        guard let ttl else { return "—" }
        return ttl == 1 ? "Auto" : "\(ttl)s"
    }

    private var overlayCardBackground: some ShapeStyle {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    private func deleteRecordsWithErrorHandling(ids: [String]) async {
        await model.deleteRecords(in: zone, recordIds: ids)
    }
}

#if os(iOS)
private struct RecordRowView: View {
    let record: ProviderRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                TypeBadge(type: record.type)
                if let priority = record.priority {
                    PriorityBadge(priority: priority)
                }

                Spacer()

                if let proxied = record.proxied {
                    CloudflareProxyIcon(isProxied: proxied)
                }

                if let ttl = record.ttl {
                    Text("TTL: \(ttlText(ttl))")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.callout.monospaced())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(recordContentText(for: record))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func recordContentText(for record: ProviderRecord) -> String {
        // For SRV records, try to extract structured data if available
        if record.type.uppercased() == "SRV" {
            switch record.recordData {
            case let .cloudflare(cfRecord):
                if let data = cfRecord.data {
                    let priority = data.priority.map(String.init) ?? "-"
                    let weight = data.weight.map(String.init) ?? "-"
                    let port = data.port.map(String.init) ?? "-"
                    let target = (data.target ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = [priority, weight, port, target.isEmpty ? "-" : target]
                    return parts.joined(separator: " ")
                }
            case .route53:
                // Route 53 SRV records are stored as plain text content
                break
            }
        }
        return record.content
    }

    private func ttlText(_ ttl: Int?) -> String {
        guard let ttl else { return "—" }
        return ttl == 1 ? "Auto" : "\(ttl)s"
    }
}
#endif
