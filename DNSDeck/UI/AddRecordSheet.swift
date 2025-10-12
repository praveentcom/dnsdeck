//
//  AddRecordSheet.swift
//  DNSDeck
//
//  Created by Praveen Thirumurugan on 12/10/25.
//


import SwiftUI
import AppKit

struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let zone: ProviderZone
    @Binding var isSubmitting: Bool

    @State private var type: String = "A"
    @State private var name: String = ""
    @State private var content: String = ""
    @State private var ttlAuto: Bool = true
    @State private var ttlValue: Int = 300
    @State private var proxied: Bool = false  // Only A/AAAA/CNAME
    @State private var mxPriority: Int = 10
    @State private var srvService: String = ""
    @State private var srvProto: String = "_tcp"
    @State private var srvDomain: String = ""
    @State private var srvPriority: Int = 10
    @State private var srvWeight: Int = 0
    @State private var srvPort: Int = 443
    @State private var srvTarget: String = ""
    @State private var ptrHostname: String = ""
    @State private var caaFlags: Int = 0
    @State private var caaTag: String = "issue"
    @State private var caaValue: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    typePicker

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
        }
        .frame(minWidth: 520)
        .onAppear(perform: syncTypeDefaults)
        .onChange(of: type) { syncTypeDefaults() }
        .alert("Error Creating Record", isPresented: $showingError) {
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

    private var typePicker: some View {
        Menu {
            typeMenuOption(value: "A", label: "A — IPv4")
            typeMenuOption(value: "AAAA", label: "AAAA — IPv6")
            typeMenuOption(value: "CNAME", label: "CNAME — Alias")
            typeMenuOption(value: "MX", label: "MX — Mail exchange")
            typeMenuOption(value: "TXT", label: "TXT — Text record")
            typeMenuOption(value: "NS", label: "NS — Nameserver")
            typeMenuOption(value: "SRV", label: "SRV — Service locator")
            typeMenuOption(value: "PTR", label: "PTR — Reverse pointer")
            typeMenuOption(value: "CAA", label: "CAA — Certificate authority")
        } label: {
            HStack {
                Text(typeLabel(for: type))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    private var namePlaceholder: String {
        switch type {
        case "SRV":
            return "Record name (e.g. _sip._tcp)"
        default:
            return "Record name (e.g. @ or www)"
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

    @ViewBuilder
    private func typeMenuOption(value: String, label: String) -> some View {
        Button {
            type = value
        } label: {
            HStack {
                Text(label)
                Spacer()
                if type == value {
                    Image(systemName: "checkmark")
                }
            }
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

        let payload = CreateProviderRecordRequest(
            name: trimmedName,
            type: type,
            content: contentValue ?? "",
            ttl: ttl,
            proxied: ["A", "AAAA", "CNAME"].contains(type) ? proxied : nil
        )

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            
            // Clear any previous errors
            await MainActor.run {
                model.error = nil
            }
            
            await model.createRecord(in: zone, payload: payload)
            
            // Check if there was an error after the operation
            await MainActor.run {
                if let error = model.error, !error.isEmpty {
                    errorMessage = error
                    showingError = true
                    model.error = nil // Clear the model error immediately to prevent double alerts
                } else {
                    // Only dismiss if there was no error
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
