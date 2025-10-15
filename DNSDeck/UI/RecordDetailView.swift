import SwiftUI

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    
    let zone: ProviderZone
    let record: ProviderRecord
    @Binding var isSubmitting: Bool
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Record Type Badge
                    HStack {
                        TypeBadge(type: record.type)
                        Spacer()
                        if let proxied = record.proxied {
                            CloudflareProxyIcon(isProxied: proxied)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Key-Value pairs
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRowView(
                            key: "Name",
                            value: record.name,
                            isMonospaced: true
                        )
                        
                        DetailRowView(
                            key: "Type",
                            value: record.type,
                            isMonospaced: true
                        )
                        
                        DetailRowView(
                            key: "Content",
                            value: recordContentText(for: record),
                            isMonospaced: true
                        )
                        
                        if let ttl = record.ttl {
                            DetailRowView(
                                key: "TTL",
                                value: ttlText(ttl),
                                isMonospaced: true
                            )
                        }
                        
                        if let priority = record.priority {
                            DetailRowView(
                                key: "Priority",
                                value: "\(priority)",
                                isMonospaced: true
                            )
                        }
                        
                        if let comment = record.comment, !comment.isEmpty {
                            DetailRowView(
                                key: "Comment",
                                value: comment,
                                isMonospaced: false
                            )
                        }
                        
                        if let createdOn = record.createdOn {
                            DetailRowView(
                                key: "Created",
                                value: createdOn.displayString(),
                                isMonospaced: false
                            )
                        }
                        
                        if let modifiedOn = record.modifiedOn {
                            DetailRowView(
                                key: "Modified",
                                value: modifiedOn.displayString(),
                                isMonospaced: false
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100) // Space for action buttons
                }
                .padding(.vertical)
            }
            .navigationTitle("Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit") {
                            showEditSheet = true
                        }
                        .disabled(isSubmitting)
                        
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .disabled(isSubmitting)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditRecordSheet(zone: zone, record: record, isSubmitting: $isSubmitting)
                .environmentObject(model)
        }
        .alert("Delete Record?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteRecord()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This record will be deleted and cannot be reversed.")
        }
        #else
        // macOS version - not needed for this task
        EmptyView()
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
    
    private func ttlText(_ ttl: Int) -> String {
        return ttl == 1 ? "Auto" : "\(ttl)s"
    }
    
    private func deleteRecord() async {
        await model.deleteRecords(in: zone, recordIds: [record.id])
        await MainActor.run {
            dismiss()
        }
    }
}

struct DetailRowView: View {
    let key: String
    let value: String
    let isMonospaced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(value)
                .font(isMonospaced ? .callout.monospaced() : .callout)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let sampleRecord = ProviderRecord(
        provider: .cloudflare,
        record: CFDNSRecord(
            id: "sample-id",
            type: "A",
            name: "example.com",
            content: "192.168.1.1",
            ttl: 300,
            proxied: true,
            proxiable: true,
            priority: nil,
            tags: nil,
            data: nil,
            created_on: Date(),
            modified_on: Date(),
            meta: nil,
            comment: "Sample comment"
        )
    )
    
    let sampleZone = ProviderZone(
        provider: .cloudflare,
        zone: CFZone(id: "zone-id", name: "example.com", status: "active")
    )
    
    return RecordDetailView(
        zone: sampleZone,
        record: sampleRecord,
        isSubmitting: .constant(false)
    )
    .environmentObject(AppModel())
}