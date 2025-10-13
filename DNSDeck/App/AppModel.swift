import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    // Replace with your own bundle id / service id
    private let cloudflareTokenStore = KeychainTokenStore(
        service: Constants.keychainService,
        account: "cloudflare.token"
    )
    private let route53CredentialsStore = KeychainRoute53CredentialsStore(service: Constants.keychainService)

    // New systems
    let errorHandler = ErrorHandler()

    lazy var cloudflareAPI = CloudflareService { [weak self] in
        (try? self?.cloudflareTokenStore.read()) ?? nil
    }

    lazy var route53API = Route53Service { [weak self] in
        guard let credentials = try? self?.route53CredentialsStore.read() else {
            return (accessKeyId: nil, secretAccessKey: nil)
        }
        return (accessKeyId: credentials.accessKeyId, secretAccessKey: credentials.secretAccessKey)
    }

    // Providers & sidebar data
    let providers: [DNSProvider] = DNSProvider.allCases
    @Published var zones: [ProviderZone] = []
    @Published var selectedZone: ProviderZone?

    // Main table data
    @Published var records: [ProviderRecord] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var zoneError: String?

    // Expose error handler for views
    var currentError: AppError? { errorHandler.currentError }
    var isShowingError: Bool { errorHandler.isShowingError }

    // Credential bindings for PreferencesView
    @Published private var editableCredentials: [DNSProvider: String] = [:]
    @Published private var editableSecondaryCredentials: [DNSProvider: String] = [:]

    init() {
        // Load Cloudflare token into binding
        if let token = try? cloudflareTokenStore.read() {
            let trimmed = token.trimmed
            if trimmed.isNotEmpty {
                editableCredentials[.cloudflare] = trimmed
            }
        }

        // Load Route 53 credentials into bindings
        if let credentials = try? route53CredentialsStore.read() {
            let trimmedAccessKey = credentials.accessKeyId.trimmed
            let trimmedSecretKey = credentials.secretAccessKey.trimmed
            if trimmedAccessKey.isNotEmpty, trimmedSecretKey.isNotEmpty {
                editableCredentials[.route53] = trimmedAccessKey
                editableSecondaryCredentials[.route53] = trimmedSecretKey
            }
        }
    }

    func credentialBinding(for provider: DNSProvider) -> Binding<String> {
        Binding(
            get: { self.editableCredentials[provider] ?? "" },
            set: { self.editableCredentials[provider] = $0 }
        )
    }

    func secondaryCredentialBinding(for provider: DNSProvider) -> Binding<String> {
        Binding(
            get: { self.editableSecondaryCredentials[provider] ?? "" },
            set: { self.editableSecondaryCredentials[provider] = $0 }
        )
    }

    func saveCredential(for provider: DNSProvider) {
        let credential = editableCredentials[provider, default: ""]

        do {
            switch provider {
            case .cloudflare:
                if credential.isEmpty {
                    try cloudflareTokenStore.delete()
                } else {
                    try cloudflareTokenStore.save(credential)
                }
            case .route53:
                let secondaryCredential = editableSecondaryCredentials[provider, default: ""]
                if credential.isEmpty || secondaryCredential.isEmpty {
                    try route53CredentialsStore.delete()
                } else {
                    let credentials = Route53Credentials(
                        accessKeyId: credential,
                        secretAccessKey: secondaryCredential
                    )
                    try route53CredentialsStore.save(credentials)
                }
            }
            // Refresh on credential change
            Task { await refreshZones() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshZones() async {
        isLoading = true
        defer { self.isLoading = false }
        var aggregated: [ProviderZone] = []

        for provider in providers {
            do {
                switch provider {
                case .cloudflare:
                    let credential = sanitizedCredential(for: provider)
                    guard credential.isNotEmpty else { continue }

                    let zones = try await cloudflareAPI.listZones()
                    let providerZones = zones.map { ProviderZone(provider: provider, zone: $0) }
                    aggregated.append(contentsOf: providerZones)

                case .route53:
                    guard isProviderConnected(provider) else { continue }

                    let zones = try await route53API.listHostedZones()
                    let providerZones = zones.map { ProviderZone(provider: provider, zone: $0) }
                    aggregated.append(contentsOf: providerZones)
                }
            } catch {
                errorHandler.handle(AppError.network(.serverError(500)))
            }
        }

        zones = aggregated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let current = selectedZone, !aggregated.contains(current) {
            selectZone(nil)
        }
    }

    func refreshRecords(for zone: ProviderZone) async {
        isLoading = true
        defer { self.isLoading = false }
        do {
            switch zone.provider {
            case .cloudflare:
                if case let .cloudflare(cfZone) = zone.zoneData {
                    let cfRecords = try await cloudflareAPI.listRecords(zoneId: cfZone.id)
                    records = cfRecords.map { ProviderRecord(provider: .cloudflare, record: $0) }
                }
            case .route53:
                if case let .route53(r53Zone) = zone.zoneData {
                    let r53Records = try await route53API.listResourceRecordSets(hostedZoneId: r53Zone.id)
                    records = r53Records.map { ProviderRecord(provider: .route53, record: $0) }
                }
            }
        } catch {
            errorHandler.handle(AppError.network(.serverError(500)))
        }
    }

    func selectZone(_ zone: ProviderZone?) {
        Task { @MainActor in
            selectedZone = zone
            if let zone {
                await refreshRecords(for: zone)
            } else {
                records.removeAll()
            }
        }
    }

    func isProviderConnected(_ provider: DNSProvider) -> Bool {
        switch provider {
        case .cloudflare:
            return !sanitizedCredential(for: provider).isEmpty
        case .route53:
            let accessKey = sanitizedCredential(for: provider)
            let secretKey = sanitizedSecondaryCredential(for: provider)
            return !accessKey.isEmpty && !secretKey.isEmpty
        }
    }

    func createRecord(in zone: ProviderZone, payload: CreateProviderRecordRequest) async {
        do {
            switch zone.provider {
            case .cloudflare:
                if case let .cloudflare(cfZone) = zone.zoneData {
                    _ = try await cloudflareAPI.createRecord(zoneId: cfZone.id, payload: payload.toCloudflareRequest())
                }
            case .route53:
                if case let .route53(r53Zone) = zone.zoneData {
                    // Get the zone name without trailing dot for conversion
                    let zoneName = r53Zone.name.hasSuffix(".") ? String(r53Zone.name.dropLast()) : r53Zone.name
                    _ = try await route53API.createRecord(
                        hostedZoneId: r53Zone.id,
                        request: payload.toRoute53Request(zoneName: zoneName)
                    )
                }
            }
            await refreshRecords(for: zone)
        } catch { self.error = error.localizedDescription }
    }

    func deleteRecords(in zone: ProviderZone, recordIds: [String]) async {
        for recordId in recordIds {
            do {
                switch zone.provider {
                case .cloudflare:
                    if case let .cloudflare(cfZone) = zone.zoneData {
                        // Extract the actual record ID from the provider record ID
                        let actualId = recordId.replacingOccurrences(of: "cloudflare|", with: "")
                        try await cloudflareAPI.deleteRecord(zoneId: cfZone.id, recordId: actualId)
                    }
                case .route53:
                    if case let .route53(r53Zone) = zone.zoneData {
                        // Find the record to delete
                        if let record = records.first(where: { $0.id == recordId }),
                           case let .route53(r53Record) = record.recordData
                        {
                            _ = try await route53API.deleteRecord(hostedZoneId: r53Zone.id, record: r53Record)
                        }
                    }
                }
            } catch { self.error = error.localizedDescription }
        }
        await refreshRecords(for: zone)
    }

    func updateRecord(in zone: ProviderZone, record: ProviderRecord, edits: UpdateProviderRecordRequest) async {
        do {
            switch zone.provider {
            case .cloudflare:
                if case let .cloudflare(cfZone) = zone.zoneData,
                   case let .cloudflare(cfRecord) = record.recordData
                {
                    _ = try await cloudflareAPI.updateRecord(
                        zoneId: cfZone.id,
                        recordId: cfRecord.id,
                        payload: edits.toCloudflareRequest()
                    )
                }
            case .route53:
                if case let .route53(r53Zone) = zone.zoneData,
                   case let .route53(r53Record) = record.recordData
                {
                    // Get the zone name without trailing dot for conversion
                    let zoneName = r53Zone.name.hasSuffix(".") ? String(r53Zone.name.dropLast()) : r53Zone.name
                    _ = try await route53API.updateRecord(
                        hostedZoneId: r53Zone.id,
                        request: edits.toRoute53Request(oldRecord: r53Record, zoneName: zoneName)
                    )
                }
            }
            await refreshRecords(for: zone)
        } catch { self.error = error.localizedDescription }
    }

    private func sanitizedCredential(for provider: DNSProvider) -> String {
        editableCredentials[provider]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func sanitizedSecondaryCredential(for provider: DNSProvider) -> String {
        editableSecondaryCredentials[provider]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
