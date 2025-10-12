//
//  RecordsView.swift
//  DNSDeck
//
//  Created by Praveen Thirumurugan on 12/10/25.
//


import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: AppModel
    let zone: ProviderZone

    @State private var selection = Set<String>()
    @State private var showAdd = false
    @State private var isSubmitting = false
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteIDs: [String] = []
    @State private var showingError = false
    @State private var errorMessage = ""

    var filteredRecords: [ProviderRecord] {
        if searchText.isEmpty { return model.records }
        let q = searchText.lowercased()
        return model.records.filter {
            $0.name.lowercased().contains(q)
            || $0.type.lowercased().contains(q)
            || recordContentText(for: $0).lowercased().contains(q)
        }
    }
    
    private var recordsTable: some View {
        Table(filteredRecords, selection: $selection) {
            TableColumn("Type") { (record: ProviderRecord) in
                typeBadge(record.type)
            }
            
            TableColumn("Name") { (record: ProviderRecord) in
                Text(record.name).textSelection(.enabled)
            }
            .width(min: 160)
            
            TableColumn("Content") { (record: ProviderRecord) in
                Text(recordContentText(for: record))
                    .textSelection(.enabled)
            }
            .width(min: 240)
            
            TableColumn("TTL") { (record: ProviderRecord) in
                Text(ttlText(record.ttl))
            }
            
            TableColumn("Proxy Status") { (record: ProviderRecord) in
                proxyStatusView(for: record)
            }
            
            TableColumn("Priority") { (record: ProviderRecord) in
                Text(record.priority.map(String.init) ?? "—")
            }
        }
    }
    
    @ViewBuilder
    private func proxyStatusView(for record: ProviderRecord) -> some View {
        if let proxied = record.proxied {
            proxyStatusIcon(isProxied: proxied)
        } else {
            Text("—")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            recordsTable
            .overlay {
                if model.isLoading {
                    LoadingOverlay(text: "Loading records…")
                    .transition(.opacity)
                }
            }
            .searchable(text: $searchText)
        }
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

                Button(role: .destructive) {
                    pendingDeleteIDs = Array(selection)
                    if !pendingDeleteIDs.isEmpty {
                        showDeleteConfirmation = true
                    }
                } label: { Label("Delete", systemImage: "trash") }
                .disabled(selection.isEmpty)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecordSheet(zone: zone, isSubmitting: $isSubmitting)
                .environmentObject(model)
                .frame(width: 520)
        }
        .alert("Delete Records?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeleteIDs
                selection.removeAll()
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
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func recordContentText(for record: ProviderRecord) -> String {
        // For SRV records, try to extract structured data if available
        if record.type.uppercased() == "SRV" {
            switch record.recordData {
            case .cloudflare(let cfRecord):
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

    @ViewBuilder
    private func typeBadge(_ type: String) -> some View {
        Text(type.uppercased())
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(badgeColor(for: type))
            )
            .help(type)
    }

    @ViewBuilder
    private func proxyStatusIcon(isProxied: Bool) -> some View {
        if isProxied {
            Image("Cloudflare")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .help("Traffic is proxied via Cloudflare")
        } else {
            Image(systemName: "bolt.horizontal.circle")
                .help("Traffic goes directly over DNS")
        }
    }

    private func badgeColor(for type: String) -> Color {
        switch type.uppercased() {
        case "A": .indigo
        case "AAAA": .purple
        case "CNAME": .pink
        case "TXT": .blue
        case "MX": .green
        case "NS": .teal
        case "SRV": .orange
        case "CAA": .red
        default: .gray
        }
    }

    private var overlayCardBackground: some ShapeStyle {
        Color(nsColor: .windowBackgroundColor)
    }
    
    private func deleteRecordsWithErrorHandling(ids: [String]) async {
        do {
            // Clear any previous errors
            await MainActor.run {
                model.error = nil
            }
            
            await model.deleteRecords(in: zone, recordIds: ids)
            
            // Check if there was an error after the operation
            await MainActor.run {
                if let error = model.error, !error.isEmpty {
                    errorMessage = error
                    showingError = true
                    model.error = nil // Clear the model error since we're handling it locally
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

private struct LoadingOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                Text(text)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
    }
}
