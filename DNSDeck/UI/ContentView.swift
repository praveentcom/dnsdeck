//
//  ContentView.swift
//  DNSDeck
//
//  Created by Praveen Thirumurugan on 12/10/25.
//


import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText: String = ""
    @State private var showingError = false

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
            List(selection: $model.selectedZone) {
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
                VStack(spacing: 12) {
                    Text("Select a domain")
                        .font(.title3)
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
        .frame(width: 20, height: 20)
    }
}
