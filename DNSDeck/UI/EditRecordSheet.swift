
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct EditRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let zone: ProviderZone
    let record: ProviderRecord
    @Binding var isSubmitting: Bool
    
    @StateObject private var localErrorHandler = ErrorHandler()

    @State private var type: String
    @State private var name: String
    @State private var content: String
    @State private var ttlAuto: Bool
    @State private var ttlValue: Int
    @State private var proxied: Bool
    @State private var mxPriority: Int
    @State private var srvService: String
    @State private var srvProto: String
    @State private var srvDomain: String
    @State private var srvPriority: Int
    @State private var srvWeight: Int
    @State private var srvPort: Int
    @State private var srvTarget: String
    @State private var ptrHostname: String
    @State private var caaFlags: Int
    @State private var caaTag: String
    @State private var caaValue: String
    
    private var timestampBackgroundColor: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor).opacity(0.5)
        #else
        Color(.systemGray6).opacity(0.5)
        #endif
    }

    init(zone: ProviderZone, record: ProviderRecord, isSubmitting: Binding<Bool>) {
        self.zone = zone
        self.record = record
        _isSubmitting = isSubmitting

        // Initialize state with existing record data
        _type = State(initialValue: record.type)
        _name = State(initialValue: record.name)
        _content = State(initialValue: record.content)
        _ttlAuto = State(initialValue: record.ttl == 1 || record.ttl == nil)
        _ttlValue = State(initialValue: record.ttl ?? 300)
        _proxied = State(initialValue: record.proxied ?? false)

        // Initialize complex record type fields with defaults
        _mxPriority = State(initialValue: record.priority ?? 10)
        _srvService = State(initialValue: "_service")
        _srvProto = State(initialValue: "_tcp")
        _srvDomain = State(initialValue: zone.name)
        _srvPriority = State(initialValue: 10)
        _srvWeight = State(initialValue: 0)
        _srvPort = State(initialValue: 443)
        _srvTarget = State(initialValue: zone.name)
        _ptrHostname = State(initialValue: record.content)
        _caaFlags = State(initialValue: 0)
        _caaTag = State(initialValue: "issue")
        _caaValue = State(initialValue: "letsencrypt.org")
    }

    var body: some View {
        #if os(iOS)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type is read-only for editing
                    HStack {
                        Text("Type")
                            .font(.headline)
                        Spacer()
                        Text(typeLabel(for: type))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    NativeTextField(placeholder: namePlaceholder, text: $name)

                    ContentField(
                        type: type,
                        content: $content,
                        ptrHostname: $ptrHostname,
                        caaValue: $caaValue,
                        srvService: $srvService,
                        srvProto: $srvProto,
                        srvDomain: $srvDomain,
                        srvTarget: $srvTarget
                    )

                    if type == "MX" {
                        MXPriorityField(mxPriority: $mxPriority)
                    }

                    if type == "SRV" {
                        SRVMetricsFields(
                            srvPriority: $srvPriority,
                            srvWeight: $srvWeight,
                            srvPort: $srvPort
                        )
                    }

                    if type == "CAA" {
                        CAADetails(
                            caaFlags: $caaFlags,
                            caaTag: $caaTag,
                            caaValue: $caaValue
                        )
                    }

                    TTLField(ttlAuto: $ttlAuto, ttlValue: $ttlValue)

                    if ["A", "AAAA", "CNAME"].contains(type) && zone.provider == .cloudflare {
                        Toggle("Proxy via Cloudflare", isOn: $proxied)
                            .toggleStyle(.switch)
                            .help("Only A/AAAA/CNAME can be proxied through Cloudflare.")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Edit DNS Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        guard !isSubmitting else { return }
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submitRecord) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Update")
                                .frame(minWidth: 60)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!formValid || isSubmitting || !hasChanges)
                }
            }
        }
        .onAppear(perform: parseExistingRecord)
        .withErrorHandling(model.errorHandler)
        #else
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type is read-only for editing
                    HStack {
                        Text("Type")
                            .font(.headline)
                        Spacer()
                        Text(typeLabel(for: type))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    NativeTextField(placeholder: namePlaceholder, text: $name)

                    ContentField(
                        type: type,
                        content: $content,
                        ptrHostname: $ptrHostname,
                        caaValue: $caaValue,
                        srvService: $srvService,
                        srvProto: $srvProto,
                        srvDomain: $srvDomain,
                        srvTarget: $srvTarget
                    )

                    if type == "MX" {
                        MXPriorityField(mxPriority: $mxPriority)
                    }

                    if type == "SRV" {
                        SRVMetricsFields(
                            srvPriority: $srvPriority,
                            srvWeight: $srvWeight,
                            srvPort: $srvPort
                        )
                    }

                    if type == "CAA" {
                        CAADetails(
                            caaFlags: $caaFlags,
                            caaTag: $caaTag,
                            caaValue: $caaValue
                        )
                    }

                    TTLField(ttlAuto: $ttlAuto, ttlValue: $ttlValue)

                    if ["A", "AAAA", "CNAME"].contains(type) && zone.provider == .cloudflare {
                        Toggle("Proxy via Cloudflare", isOn: $proxied)
                            .toggleStyle(.switch)
                            .help("Only A/AAAA/CNAME can be proxied through Cloudflare.")
                    }
                    
                    // Timestamp information (Cloudflare only)
                    if zone.provider == .cloudflare {
                        timestampSection
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Edit DNS Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        guard !isSubmitting else { return }
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submitRecord) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Update")
                                .frame(minWidth: 60)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!formValid || isSubmitting || !hasChanges)
                }
            }
            .onAppear(perform: parseExistingRecord)
            .withErrorHandling(localErrorHandler)
        }
        #if os(macOS)
        .frame(minWidth: 520)
        #endif
        #endif
    }

    private var namePlaceholder: String {
        switch type {
        case "SRV":
            "Record name (e.g. _sip._tcp)"
        default:
            "Record name (e.g. @ or www)"
        }
    }
    
    private var timestampSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Record Information")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
                if let createdOn = record.createdOn {
                    HStack {
                        Text("Created:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(createdOn.displayString())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let modifiedOn = record.modifiedOn {
                    HStack {
                        Text("Last Modified:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(modifiedOn.displayString())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if record.createdOn == nil && record.modifiedOn == nil {
                    Text("Timestamp information not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(timestampBackgroundColor)
        .cornerRadius(8)
    }

    private func parseExistingRecord() {
        // Parse existing record data for complex types
        switch type {
        case "SRV":
            parseSRVRecord()
        case "PTR":
            ptrHostname = record.content
        case "CAA":
            parseCAARecord()
        case "MX":
            // Priority is already set from record.priority
            break
        default:
            break
        }
    }

    private func parseSRVRecord() {
        // Try to parse SRV record from content or structured data
        if case let .cloudflare(cfRecord) = record.recordData,
           let data = cfRecord.data
        {
            srvPriority = data.priority ?? 10
            srvWeight = data.weight ?? 0
            srvPort = data.port ?? 443
            srvTarget = data.target ?? zone.name

            // Parse service and protocol from name
            let parts = record.name.components(separatedBy: ".")
            if parts.count >= 2 {
                srvService = parts[0]
                srvProto = parts[1]
                if parts.count > 2 {
                    srvDomain = parts.dropFirst(2).joined(separator: ".")
                }
            }
        } else {
            // Parse from content string for Route53 or fallback
            let contentParts = record.content.components(separatedBy: " ")
            if contentParts.count >= 4 {
                srvPriority = Int(contentParts[0]) ?? 10
                srvWeight = Int(contentParts[1]) ?? 0
                srvPort = Int(contentParts[2]) ?? 443
                srvTarget = contentParts[3]
            }
        }
    }

    private func parseCAARecord() {
        // Parse CAA record from content
        let parts = record.content.components(separatedBy: " ")
        if parts.count >= 3 {
            caaFlags = Int(parts[0]) ?? 0
            caaTag = parts[1]
            caaValue = parts.dropFirst(2).joined(separator: " ")
        }
    }

    private func typeLabel(for type: String) -> String {
        switch type {
        case "A":
            "A — IPv4"
        case "AAAA":
            "AAAA — IPv6"
        case "CNAME":
            "CNAME — Alias"
        case "MX":
            "MX — Mail exchange"
        case "TXT":
            "TXT — Text record"
        case "NS":
            "NS — Nameserver"
        case "SRV":
            "SRV — Service locator"
        case "PTR":
            "PTR — Reverse pointer"
        case "CAA":
            "CAA — Certificate authority"
        default:
            type.uppercased()
        }
    }

    private func submitRecord() {
        guard !isSubmitting else { return }

        let ttl = ttlAuto ? 1 : ttlValue

        let payload = UpdateProviderRecordRequest(
            name: hasNameChanged ? trimmedName : nil,
            type: nil, // Type cannot be changed
            content: hasContentChanged ? contentValue : nil,
            ttl: hasTTLChanged ? ttl : nil,
            proxied: hasProxiedChanged ? (["A", "AAAA", "CNAME"].contains(type) ? proxied : nil) : nil,
            priority: hasPriorityChanged ? (type == "MX" ? mxPriority : nil) : nil
        )

        Task {
            isSubmitting = true
            defer { isSubmitting = false }

            // Clear any previous errors
            localErrorHandler.clearError()

            do {
                // Call the model's update function directly but handle errors locally
                switch zone.provider {
                case .cloudflare:
                    if case let .cloudflare(cfZone) = zone.zoneData,
                       case let .cloudflare(cfRecord) = record.recordData
                    {
                        _ = try await model.cloudflareAPI.updateRecord(
                            zoneId: cfZone.id,
                            recordId: cfRecord.id,
                            payload: payload.toCloudflareRequest()
                        )
                    }
                case .route53:
                    if case let .route53(r53Zone) = zone.zoneData,
                       case let .route53(r53Record) = record.recordData
                    {
                        let zoneName = r53Zone.name.hasSuffix(".") ? String(r53Zone.name.dropLast()) : r53Zone.name
                        _ = try await model.route53API.updateRecord(
                            hostedZoneId: r53Zone.id,
                            request: payload.toRoute53Request(oldRecord: r53Record, zoneName: zoneName)
                        )
                    }
                }
                
                // If successful, refresh records and dismiss
                await model.refreshRecords(for: zone)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Handle error locally
                localErrorHandler.handle(error)
            }
        }
    }

    private var formValid: Bool {
        guard !trimmedName.isEmpty else { return false }

        switch type {
        case "SRV":
            return recordData != nil
        case "PTR":
            return contentValue != nil
        case "CAA":
            return recordData != nil
        default:
            return contentValue != nil
        }
    }

    private var hasChanges: Bool {
        hasNameChanged || hasContentChanged || hasTTLChanged || hasProxiedChanged || hasPriorityChanged
    }

    private var hasNameChanged: Bool {
        trimmedName != record.name
    }

    private var hasContentChanged: Bool {
        guard let newContent = contentValue else { return false }
        return newContent != record.content
    }

    private var hasTTLChanged: Bool {
        let newTTL = ttlAuto ? 1 : ttlValue
        return newTTL != (record.ttl ?? 1)
    }

    private var hasProxiedChanged: Bool {
        guard ["A", "AAAA", "CNAME"].contains(type) else { return false }
        return proxied != (record.proxied ?? false)
    }

    private var hasPriorityChanged: Bool {
        guard type == "MX" else { return false }
        return mxPriority != (record.priority ?? 10)
    }

    private var trimmedName: String {
        name.trimmed
    }

    private var contentValue: String? {
        switch type {
        case "SRV":
            return nil
        case "PTR":
            let trimmed = ptrHostname.trimmed
            return trimmed.isEmpty ? nil : trimmed
        case "CAA":
            return nil
        default:
            let trimmed = content.trimmed
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var recordData: RecordData? {
        switch type {
        case "SRV":
            let service = srvService.trimmed
            let domain = srvDomain.trimmed
            let target = srvTarget.trimmed
            guard service.isNotEmpty, domain.isNotEmpty, target.isNotEmpty else { return nil }
            return RecordData(
                service: service,
                proto: srvProto,
                name: domain,
                priority: srvPriority,
                weight: srvWeight,
                port: srvPort,
                target: target,
                flags: nil,
                tag: nil,
                value: nil
            )
        case "CAA":
            let value = caaValue.trimmed
            guard value.isNotEmpty else { return nil }
            return RecordData(
                service: nil,
                proto: nil,
                name: nil,
                priority: nil,
                weight: nil,
                port: nil,
                target: nil,
                flags: caaFlags,
                tag: caaTag,
                value: value
            )
        default:
            return nil
        }
    }
}
