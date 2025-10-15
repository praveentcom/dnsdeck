

import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: AppModel
    let zone: ProviderZone

    @State private var showAdd = false
    @State private var isSubmitting = false
    @StateObject private var debouncedSearch = DebouncedSearch()
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteIDs: [String] = []
    @State private var selectedRecord: ProviderRecord?
    
    // Multi-selection state for macOS
    #if os(macOS)
    @State private var selectedRecordIDs: Set<String> = []
    @State private var showCSVImport = false
    @State private var showCommentColumn = false
    #endif

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
        Table(filteredRecords, selection: $selectedRecordIDs) {
            TableColumn("") { (record: ProviderRecord) in
                EmptyView()
            }
            .width(min: 30, ideal: 30, max: 30)
            
            TableColumn("Type") { (record: ProviderRecord) in
                TypeBadge(type: record.type)
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Name") { (record: ProviderRecord) in
                Text(record.name).textSelection(.enabled)
            }
            .width(min: Constants.UI.tableColumnMinWidth, ideal: 200, max: .infinity)

            TableColumn("Content") { (record: ProviderRecord) in
              HStack(alignment: .center, spacing: 6) {
                  if let proxied = record.proxied {
                      CloudflareProxyIcon(isProxied: proxied)
                  }
                  Text(recordContentText(for: record))
                    .textSelection(.enabled)
                }
            }
            .width(min: Constants.UI.contentColumnMinWidth, ideal: 300, max: .infinity)

            TableColumn("TTL") { (record: ProviderRecord) in
                Text(ttlText(record.ttl))
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("Priority") { (record: ProviderRecord) in
                if let priority = record.priority {
                    PriorityBadge(priority: priority)
                }
            }
            .width(min: 60, ideal: 80, max: 80)
            
            TableColumn("Modified") { (record: ProviderRecord) in
                if let modifiedOn = record.modifiedOn {
                    Text(modifiedOn.compactString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .help("Last modified: \(modifiedOn.displayString())")
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120, ideal: 120, max: 200)
            
            // Comment column (optional, Cloudflare only)
            if showCommentColumn && zone.provider == .cloudflare {
                TableColumn("Comment") { (record: ProviderRecord) in
                    if let comment = record.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .help(comment)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .width(min: 100, ideal: 150, max: 200)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: ProviderRecord.ID.self) { items in
            if items.count == 1, let recordId = items.first,
               let record = model.records.first(where: { $0.id == recordId })
            {
                Button("Edit") {
                    selectedRecord = record
                }
                .disabled(isSubmitting)

                Divider()

                Button("Delete", role: .destructive) {
                    pendingDeleteIDs = [recordId]
                    showDeleteConfirmation = true
                }
                .disabled(isSubmitting)
            } else if items.count > 1 {
                Button("Delete \(items.count) Records", role: .destructive) {
                    pendingDeleteIDs = Array(items)
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
                    Button("Delete", role: .none) {
                        pendingDeleteIDs = [record.id]
                        showDeleteConfirmation = true
                    }
                    .disabled(isSubmitting)
                    .tint(.red)

                    Button("Edit") {
                        selectedRecord = record
                    }
                    .disabled(isSubmitting)
                }
                .contextMenu {
                    Button("Edit") {
                        selectedRecord = record
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
                #if os(macOS)
                if !selectedRecordIDs.isEmpty {
                    Button {
                        pendingDeleteIDs = Array(selectedRecordIDs)
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete \(selectedRecordIDs.count) record\(selectedRecordIDs.count == 1 ? "" : "s")", 
                              systemImage: "trash")
                    }
                    .disabled(isSubmitting)
                }
                
                Button {
                    showCSVImport = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                .disabled(isSubmitting)
                
                // Toggle comment column (Cloudflare only)
                if zone.provider == .cloudflare {
                    Button {
                        showCommentColumn.toggle()
                    } label: {
                        Label("Comments", systemImage: showCommentColumn ? "text.bubble.fill" : "text.bubble")
                    }
                    .help(showCommentColumn ? "Hide comment column" : "Show comment column")
                }
                #endif
                
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
        .sheet(item: $selectedRecord) { record in
            EditRecordSheet(zone: zone, record: record, isSubmitting: $isSubmitting)
                .environmentObject(model)
            #if os(macOS)
                .frame(width: 520)
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: $showCSVImport) {
            CSVImportSheet(zone: zone, isSubmitting: $isSubmitting)
                .environmentObject(model)
        }
        #endif
        .alert("Delete Records?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeleteIDs
                pendingDeleteIDs = []
                #if os(macOS)
                selectedRecordIDs.removeAll()
                #endif
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
        #if os(macOS)
        .onChange(of: model.records) {
            // Clear selection when records change (e.g., after refresh or zone change)
            selectedRecordIDs.removeAll()
        }
        .onKeyPress(.escape) {
            // Clear selection when escape is pressed
            selectedRecordIDs.removeAll()
            return .handled
        }
        #endif
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
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading) {
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
