

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText: String = ""
    @State private var showingError = false
    
    private var selectedZoneBinding: Binding<ProviderZone?> {
        Binding(
            get: { model.selectedZone },
            set: { model.selectZone($0) }
        )
    }

    private var filteredZones: [ProviderZone] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return model.zones
        }
        let query = searchText.lowercased()
        return model.zones.filter { zone in
            zone.name.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selectedZoneBinding) {
                Section("Domains") {
                    if filteredZones.isEmpty {
                        Text(model.isLoading ? "Loading…" : "No zones found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredZones) { zone in
                            NavigationLink(value: zone) {
                                HStack(spacing: 8) {
                                    providerTag(for: zone.provider)
                                    Text(zone.name)
                                }
                                .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("DNSDeck")
            .searchable(text: $searchText, placement: .sidebar)
        } detail: {
            if let zone = model.selectedZone {
                RecordsView(zone: zone)
            } else {
                VStack(spacing: 8) {
                    Text("Select a domain to manage DNS records")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("To connect providers, open Settings (⌘,)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Error Loading Zones", isPresented: $showingError) {
            Button("OK") {
                model.zoneError = nil
            }
        } message: {
            Text(model.zoneError ?? "An unknown error occurred")
        }
        .onChange(of: model.zoneError) { _, newError in
            if newError != nil && !newError!.isEmpty {
                showingError = true
            }
        }
    }

    private func providerTag(for provider: DNSProvider) -> some View {
      Image(provider.imageName)
        .resizable()
        .frame(width: 24, height: 24)
    }
}
