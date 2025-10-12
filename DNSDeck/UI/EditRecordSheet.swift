
import SwiftUI
import AppKit

struct EditRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let zone: ProviderZone
    let record: ProviderRecord
    @Binding var isSubmitting: Bool

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
    @State private var showingError = false
    @State private var errorMessage = ""

    init(zone: ProviderZone, record: ProviderRecord, isSubmitting: Binding<Bool>) {
        self.zone = zone
        self.record = record
        self._isSubmitting = isSubmitting
        
        // Initialize state with existing record data
        self._type = State(initialValue: record.type)
        self._name = State(initialValue: record.name)
        self._content = State(initialValue: record.content)
        self._ttlAuto = State(initialValue: record.ttl == 1 || record.ttl == nil)
        self._ttlValue = State(initialValue: record.ttl ?? 300)
        self._proxied = State(initialValue: record.proxied ?? false)
        
        // Initialize complex record type fields with defaults
        self._mxPriority = State(initialValue: record.priority ?? 10)
        self._srvService = State(initialValue: "_service")
        self._srvProto = State(initialValue: "_tcp")
        self._srvDomain = State(initialValue: zone.name)
        self._srvPriority = State(initialValue: 10)
        self._srvWeight = State(initialValue: 0)
        self._srvPort = State(initialValue: 443)
        self._srvTarget = State(initialValue: zone.name)
        self._ptrHostname = State(initialValue: record.content)
        self._caaFlags = State(initialValue: 0)
        self._caaTag = State(initialValue: "issue")
        self._caaValue = State(initialValue: "letsencrypt.org")
    }

    var body: some View {
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

                    TextField(namePlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)

                    contentField

                    if type == "MX" {
                        mxPriorityField
                    }

                    if type == "SRV" {
                        srvMetricsFields
                    }

                    if type == "CAA" {
                        caaDetails
                    }

                    ttlField

                    if ["A", "AAAA", "CNAME"].contains(type) {
                        Toggle("Proxied (orange cloud)", isOn: $proxied)
                            .toggleStyle(.switch)
                            .help("Only A/AAAA/CNAME can be proxied through Cloudflare.")
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
        }
        .frame(minWidth: 520)
        .onAppear(perform: parseExistingRecord)
        .alert("Error Updating Record", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var contentField: some View {
        Group {
            switch type {
            case "TXT":
                TextField("TXT value", text: $content, axis: .vertical)
                    .lineLimit(4)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 48, alignment: .top)
            case "MX":
                TextField("Mail server (e.g. mx1.example.com.)", text: $content)
                    .textFieldStyle(.roundedBorder)
            case "A":
                TextField("IPv4 address (e.g. 8.8.8.8)", text: $content)
                    .textFieldStyle(.roundedBorder)
            case "AAAA":
                TextField("IPv6 address (e.g. 2001:4860:4860::8888)", text: $content)
                    .textFieldStyle(.roundedBorder)
            case "CNAME":
                TextField("Target hostname (e.g. app.example.com.)", text: $content)
                    .textFieldStyle(.roundedBorder)
            case "NS":
                TextField("Authoritative nameserver (e.g. ns1.example.com.)", text: $content)
                    .textFieldStyle(.roundedBorder)
            case "SRV":
                srvFields
            case "PTR":
                TextField("Host target (e.g. mail.example.com.)", text: $ptrHostname)
                    .textFieldStyle(.roundedBorder)
            case "CAA":
                TextField("Issuer domain (e.g. letsencrypt.org)", text: $caaValue)
                    .textFieldStyle(.roundedBorder)
            default:
                TextField("Value", text: $content)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var mxPriorityField: some View {
        TextField("Priority", value: $mxPriority, format: .number)
            .textFieldStyle(.roundedBorder)
            .onChange(of: mxPriority) { _, newValue in
                mxPriority = min(max(newValue, 0), 65535)
            }
    }

    private var srvFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Service (e.g. _sip)", text: $srvService)
                    .textFieldStyle(.roundedBorder)

                Picker("Protocol", selection: $srvProto) {
                    ForEach(["_tcp", "_udp", "_tls"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            TextField("Domain (e.g. example.com)", text: $srvDomain)
                .textFieldStyle(.roundedBorder)

            TextField("Target host (e.g. sip.example.com.)", text: $srvTarget)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var srvMetricsFields: some View {
        HStack(spacing: 12) {
            TextField("Priority", value: $srvPriority, format: .number)
                .textFieldStyle(.roundedBorder)
            TextField("Weight", value: $srvWeight, format: .number)
                .textFieldStyle(.roundedBorder)
            TextField("Port", value: $srvPort, format: .number)
                .textFieldStyle(.roundedBorder)
        }
        .onChange(of: srvPriority) { _, newValue in
            srvPriority = min(max(newValue, 0), 65535)
        }
        .onChange(of: srvWeight) { _, newValue in
            srvWeight = min(max(newValue, 0), 65535)
        }
        .onChange(of: srvPort) { _, newValue in
            srvPort = min(max(newValue, 1), 65535)
        }
    }

    private var caaDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: $caaFlags, in: 0...255) {
                HStack {
                    Text("Flags")
                    Spacer()
                    Text(String(caaFlags))
                        .monospacedDigit()
                }
            }

            Picker("Tag", selection: $caaTag) {
                ForEach(["issue", "issuewild", "iodef"], id: \.self) { tag in
                    Text(tag).tag(tag)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var ttlField: some View {
        HStack(spacing: 12) {
            Toggle("Automatic TTL", isOn: $ttlAuto)
            Spacer()
            TextField("Seconds", value: $ttlValue, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .disabled(ttlAuto)
                .opacity(ttlAuto ? 0.45 : 1)
        }
        .help("Cloudflare TTL of 1 means 'Automatic'.")
        .onChange(of: ttlValue) { _, newValue in
            ttlValue = min(max(newValue, 60), 86400)
        }
    }

    private var namePlaceholder: String {
        switch type {
        case "SRV":
            return "Record name (e.g. _sip._tcp)"
        default:
            return "Record name (e.g. @ or www)"
        }
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
        if case .cloudflare(let cfRecord) = record.recordData,
           let data = cfRecord.data {
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
            return "A — IPv4"
        case "AAAA":
            return "AAAA — IPv6"
        case "CNAME":
            return "CNAME — Alias"
        case "MX":
            return "MX — Mail exchange"
        case "TXT":
            return "TXT — Text record"
        case "NS":
            return "NS — Nameserver"
        case "SRV":
            return "SRV — Service locator"
        case "PTR":
            return "PTR — Reverse pointer"
        case "CAA":
            return "CAA — Certificate authority"
        default:
            return type.uppercased()
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
            proxied: hasProxiedChanged ? (["A", "AAAA", "CNAME"].contains(type) ? proxied : nil) : nil
        )

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            
            // Clear any previous errors
            model.error = nil
            
            await model.updateRecord(in: zone, record: record, edits: payload)
            
            // Check if there was an error after the operation
            if let error = model.error, !error.isEmpty {
                await MainActor.run {
                    errorMessage = error
                    showingError = true
                }
                model.error = nil // Clear the model error immediately to prevent double alerts
            } else {
                // Only dismiss if there was no error
                await MainActor.run {
                    dismiss()
                }
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
        hasNameChanged || hasContentChanged || hasTTLChanged || hasProxiedChanged
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

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contentValue: String? {
        switch type {
        case "SRV":
            return nil
        case "PTR":
            let trimmed = ptrHostname.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case "CAA":
            return nil
        default:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var recordData: RecordData? {
        switch type {
        case "SRV":
            let service = srvService.trimmingCharacters(in: .whitespacesAndNewlines)
            let domain = srvDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = srvTarget.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !service.isEmpty, !domain.isEmpty, !target.isEmpty else { return nil }
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
            let value = caaValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
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