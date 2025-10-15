#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct CSVImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    
    let zone: ProviderZone
    @Binding var isSubmitting: Bool
    
    @StateObject private var localErrorHandler = ErrorHandler()
    
    @State private var selectedFileURL: URL?
    @State private var parseResult: CSVParseResult?
    @State private var showingFilePicker = false
    @State private var importProgress: Double = 0.0
    @State private var isImporting = false
    @State private var importedCount = 0
    @State private var failedCount = 0
    @State private var showingProgressDetails = false
    @State private var bulkComment = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // File Selection Section
                fileSelectionSection
                
                // Preview Section
                if let parseResult = parseResult {
                    previewSection(parseResult: parseResult)
                }
                
                // Bulk Comment Section (Cloudflare only)
                if zone.provider == .cloudflare && parseResult != nil {
                    bulkCommentSection
                }
                
                Spacer()
            }
            .padding(20)
            .frame(minWidth: 600, minHeight: 400)
            .navigationTitle("Import from CSV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        guard !isImporting else { return }
                        dismiss()
                    }
                    .disabled(isImporting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: importRecords) {
                        if isImporting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Importing...")
                            }
                        } else {
                            Text("Import \(parseResult?.records.count ?? 0) Record\(parseResult?.records.count == 1 ? "" : "s")")
                        }
                    }
                    .disabled(!canImport || isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .withErrorHandling(localErrorHandler)
        }
    }
    
    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let selectedFileURL = selectedFileURL {
                        Text(selectedFileURL.lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                        Text(selectedFileURL.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No file selected")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Choose File...") {
                    showingFilePicker = true
                }
                .disabled(isImporting)
            }
            
            if parseResult == nil {
              VStack(alignment: .leading, spacing: 8) {
                  Text("Format Requirements:")
                      .font(.subheadline)
                      .fontWeight(.medium)
                  
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Required columns: Type, Name, Value")
                    Text("• Optional columns: TTL, Priority, Proxied, Comment")
                    Text("• First row must contain column headers")
                    Text("• Supported record types: A, AAAA, CNAME, MX, TXT, NS, SRV, CAA, PTR")
                    if zone.provider == .cloudflare {
                        Text("• Bulk comment can be added to all records during import")
                    }
                }
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
        }
    }
    
    private func previewSection(parseResult: CSVParseResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if parseResult.hasWarnings {
                    Label("\(parseResult.errors.filter { $0.severity == .warning }.count) warnings", 
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                if !parseResult.isValid {
                    Label("\(parseResult.errors.filter { $0.severity == .error }.count) errors", 
                          systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if !parseResult.errors.isEmpty {
                errorsList(errors: parseResult.errors)
            }
            
            if !parseResult.records.isEmpty {
                recordsPreview(records: parseResult.records)
            }
        }
    }
    
    private func errorsList(errors: [CSVParseError]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(errors) { error in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(error.severity == .error ? .red : .orange)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Line \(error.line): \(error.message)")
                                .font(.caption)
                            
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: 100)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private func recordsPreview(records: [CSVRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(records.count) records to import:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    // Header
                    HStack {
                        Text("Type")
                            .frame(width: 60, alignment: .leading)
                        Text("Name")
                            .frame(minWidth: 120, alignment: .leading)
                        Text("Value")
                            .frame(minWidth: 200, alignment: .leading)
                        Text("TTL")
                            .frame(width: 60, alignment: .leading)
                        Text("Priority")
                            .frame(width: 60, alignment: .leading)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    ForEach(Array(records.prefix(10).enumerated()), id: \.offset) { index, record in
                        HStack {
                            Text(record.type)
                                .frame(width: 60, alignment: .leading)
                                .font(.system(.caption, design: .monospaced))
                            
                            Text(record.name)
                                .frame(minWidth: 120, alignment: .leading)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(record.value)
                                .frame(minWidth: 200, alignment: .leading)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(record.ttl.map(String.init) ?? "—")
                                .frame(width: 60, alignment: .leading)
                                .font(.system(.caption, design: .monospaced))
                            
                            Text(record.priority.map(String.init) ?? "—")
                                .frame(width: 60, alignment: .leading)
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(.vertical, 2)
                        .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.3))
                    }
                    
                    if records.count > 10 {
                        Text("... and \(records.count - 10) more records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
    }
    
    private var bulkCommentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("(Optional) Upload Comment:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Add a comment for all imported records", text: $bulkComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• This comment will be added to all imported records")
                Text("• If a record has its own comment, this will be prepended")
                Text("• If a record has no comment, this will be used as the comment")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var canImport: Bool {
        guard let parseResult = parseResult else { return false }
        return parseResult.isValid && !parseResult.records.isEmpty
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            parseCSVFile(url)
        case .failure(let error):
            localErrorHandler.handle(error)
        }
    }
    
    private func parseCSVFile(_ url: URL) {
        do {
            let result = try CSVParser.parse(from: url)
            parseResult = result
            
            if !result.isValid {
                // Show first error if parsing failed
                if let firstError = result.errors.first(where: { $0.severity == .error }) {
                    localErrorHandler.handle(AppError.general(firstError.message))
                }
            }
        } catch {
            localErrorHandler.handle(error)
            parseResult = nil
        }
    }
    
    private func importRecords() {
        guard let parseResult = parseResult, parseResult.isValid else { return }
        
        Task {
            isImporting = true
            isSubmitting = true
            importProgress = 0.0
            importedCount = 0
            failedCount = 0
            
            defer {
                isImporting = false
                isSubmitting = false
            }
            
            let requests = parseResult.records.map { csvRecord in
                var request = csvRecord.toCreateProviderRecordRequest()
                
                // Apply bulk comment logic for Cloudflare
                if zone.provider == .cloudflare && !bulkComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedBulkComment = bulkComment.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let existingComment = request.comment, !existingComment.isEmpty {
                        // Prepend bulk comment to existing comment
                        request = CreateProviderRecordRequest(
                            name: request.name,
                            type: request.type,
                            content: request.content,
                            ttl: request.ttl,
                            proxied: request.proxied,
                            priority: request.priority,
                            comment: "\(trimmedBulkComment) | \(existingComment)"
                        )
                    } else {
                        // Use bulk comment as the comment
                        request = CreateProviderRecordRequest(
                            name: request.name,
                            type: request.type,
                            content: request.content,
                            ttl: request.ttl,
                            proxied: request.proxied,
                            priority: request.priority,
                            comment: trimmedBulkComment
                        )
                    }
                }
                
                return request
            }
            
            let result = await model.createRecordsBatch(in: zone, records: requests) { progress in
                importProgress = progress
            }
            
            importedCount = result.successfulRecords
            failedCount = result.failedRecords
            
            await MainActor.run {
                if result.isCompleteSuccess {
                    dismiss()
                } else {
                    // Show detailed error summary
                    var message = "Import completed: \(result.successfulRecords) successful, \(result.failedRecords) failed"
                    
                    if !result.errors.isEmpty {
                        let errorSummary = result.errors.prefix(3).map { error in
                            "\(error.recordName): \(error.error.localizedDescription)"
                        }.joined(separator: "\n")
                        
                        if result.errors.count > 3 {
                            message += "\n\nFirst few errors:\n\(errorSummary)\n... and \(result.errors.count - 3) more"
                        } else {
                            message += "\n\nErrors:\n\(errorSummary)"
                        }
                    }
                    
                    localErrorHandler.handle(AppError.general(message))
                }
            }
        }
    }
}

#endif
