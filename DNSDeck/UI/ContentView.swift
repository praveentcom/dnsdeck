

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var debouncedSearch = DebouncedSearch()
    @State private var showingError = false
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    private var selectedZoneBinding: Binding<ProviderZone?> {
        Binding(
            get: { model.selectedZone },
            set: { model.selectZone($0) }
        )
    }

    private var filteredZones: [ProviderZone] {
        guard !debouncedSearch.debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return model.zones
        }
        let query = debouncedSearch.debouncedSearchText.lowercased()
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
            .searchable(text: $debouncedSearch.searchText, placement: .sidebar)
            #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            #endif
        } detail: {
            if let zone = model.selectedZone {
                RecordsView(zone: zone)
            } else {
                VStack(spacing: 8) {
                    Text("Select a domain to manage DNS records")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    #if os(macOS)
                    Text("To connect providers, open Settings (⌘,)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    #else
                    Text("To connect providers, tap the settings icon")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    #endif
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task { await model.refreshZones() }
        }) {
            NavigationView {
                PreferencesView()
                    .environmentObject(model)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
        #endif
        .alert("Error Loading Zones", isPresented: $showingError) {
            Button("OK") {
                model.zoneError = nil
            }
        } message: {
            Text(model.zoneError ?? "An unknown error occurred")
        }
        .onChange(of: model.zoneError) { _, newError in
            if newError != nil, !newError!.isEmpty {
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
