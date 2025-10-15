

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let zone: ProviderZone
    @Binding var isSubmitting: Bool
    
    @StateObject private var localErrorHandler = ErrorHandler()

    @State private var type = "A"
    @State private var name = ""
    @State private var content = ""
    @State private var ttlAuto = true
    @State private var ttlValue = 300
    @State private var proxied = false // Only A/AAAA/CNAME
    @State private var mxPriority = 10
    @State private var srvService = ""
    @State private var srvProto = "_tcp"
    @State private var srvDomain = ""
    @State private var srvPriority = 10
    @State private var srvWeight = 0
    @State private var srvPort = 443
    @State private var srvTarget = ""
    @State private var ptrHostname = ""
    @State private var caaFlags = 0
    @State private var caaTag = "issue"
    @State private var caaValue = ""
    @State private var comment = ""

    var body: some View {
        #if os(iOS)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TypePicker(type: $type)

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
                    
                    // Comment field (Cloudflare only)
                    if zone.provider == .cloudflare {
                        #if os(iOS)
                        NativeTextField(placeholder: "Add a comment for this record (optional)", text: $comment)
                        #else
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comment (Optional)")
                                .font(.headline)
                            NativeTextField(placeholder: "Add a comment for this record", text: $comment)
                        }
                        #endif
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Add DNS Record")
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
                            Text("Add")
                                .frame(minWidth: 60)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!formValid || isSubmitting)
                }
            }
        }
        #else
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TypePicker(type: $type)

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
                    
                    // Comment field (Cloudflare only)
                    if zone.provider == .cloudflare {
                        #if os(iOS)
                        NativeTextField(placeholder: "Add a comment for this record (optional)", text: $comment)
                        #else
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comment (Optional)")
                                .font(.headline)
                            NativeTextField(placeholder: "Add a comment for this record", text: $comment)
                        }
                        #endif
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Add DNS Record")
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
                            Text("Add")
                                .frame(minWidth: 60)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!formValid || isSubmitting)
                }
            }
            .onAppear(perform: syncTypeDefaults)
            .onChange(of: type) { syncTypeDefaults() }
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

    private func syncTypeDefaults() {
        switch type {
        case "SRV":
            if srvDomain.isEmpty { srvDomain = zone.name }
            if srvService.isEmpty { srvService = "_service" }
            if name.isEmpty { name = "_service._tcp" }
            if srvTarget.isEmpty { srvTarget = zone.name }
        case "PTR":
            if ptrHostname.isEmpty { ptrHostname = zone.name }
        case "CAA":
            if caaValue.isEmpty { caaValue = "letsencrypt.org" }
        default:
            break
        }
    }

    private func submitRecord() {
        guard !isSubmitting else { return }

        let ttl = ttlAuto ? 1 : ttlValue

        let payload = CreateProviderRecordRequest(
            name: trimmedName,
            type: type,
            content: contentValue ?? "",
            ttl: ttl,
            proxied: ["A", "AAAA", "CNAME"].contains(type) ? proxied : nil,
            priority: type == "MX" ? mxPriority : nil,
            comment: comment.trimmed.isEmpty ? nil : comment.trimmed
        )

        Task {
            isSubmitting = true
            defer { isSubmitting = false }

            // Clear any previous errors
            localErrorHandler.clearError()

            do {
                // Call the model's create function directly but handle errors locally
                switch zone.provider {
                case .cloudflare:
                    if case let .cloudflare(cfZone) = zone.zoneData {
                        _ = try await model.cloudflareAPI.createRecord(zoneId: cfZone.id, payload: payload.toCloudflareRequest())
                    }
                case .route53:
                    if case let .route53(r53Zone) = zone.zoneData {
                        let zoneName = r53Zone.name.hasSuffix(".") ? String(r53Zone.name.dropLast()) : r53Zone.name
                        _ = try await model.route53API.createRecord(
                            hostedZoneId: r53Zone.id,
                            request: payload.toRoute53Request(zoneName: zoneName)
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
