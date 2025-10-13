import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(model.providers) { provider in
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center, spacing: 8) {
                                    Image(provider.imageName)
                                        .resizable()
                                        .frame(width: 24, height: 24)

                                    Text(provider.displayName)
                                        .font(.title3.weight(.semibold))

                                    if model.isProviderConnected(provider) {
                                        Image(systemName: "circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.system(size: 6))
                                            .accessibilityLabel("Connected")
                                    }
                                }

                                Text(provider.description)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                credentialFields(for: provider)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .tabItem {
                Label("Providers", systemImage: "antenna.radiowaves.left.and.right")
            }

            // About Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DNSDeck")
                                .font(.title2.weight(.semibold))

                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                            {
                                Text("Version \(version) (\(build))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        #if os(macOS)
                        Text(
                            "A powerful DNS management tool for macOS that helps you manage your DNS records across multiple providers including Cloudflare, Amazon Route 53 and more."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        #else
                        Text(
                            "A powerful DNS management tool for iOS that helps you manage your DNS records across multiple providers including Cloudflare, Amazon Route 53 and more."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        #endif
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(
                                icon: "cloud",
                                title: "Multi-Provider Support",
                                description: "Manage DNS records across multiple cloud providers"
                            )
                            FeatureRow(
                                icon: "lock.shield",
                                title: "Secure Credential Storage",
                                description: "Credentials are stored in your iCloud Keychain"
                            )
                            FeatureRow(
                                icon: "magnifyingglass",
                                title: "Search & Filter",
                                description: "Quickly find domain zones and DNS records"
                            )
                            FeatureRow(
                                icon: "plus.circle",
                                title: "Easy Record Management",
                                description: "Add, edit, and delete DNS records with ease"
                            )
                            FeatureRow(
                                icon: "arrow.clockwise",
                                title: "Real-time Updates",
                                description: "Changes are reflected immediately in your DNS provider"
                            )
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .tabViewStyle(.automatic)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private func credentialFields(for provider: DNSProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(provider.credentialFieldLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            NativeSecureField(placeholder: provider.credentialPlaceholder, text: model.credentialBinding(for: provider))
                .onChange(of: model.credentialBinding(for: provider).wrappedValue) { _, _ in
                    saveCredentialWithErrorHandling(for: provider)
                }

            // Secondary credential field for providers that require it (like Route 53)
            if provider.requiresSecondaryCredential,
               let secondaryLabel = provider.secondaryCredentialFieldLabel,
               let secondaryPlaceholder = provider.secondaryCredentialPlaceholder
            {
                Text(secondaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NativeSecureField(
                    placeholder: secondaryPlaceholder,
                    text: model.secondaryCredentialBinding(for: provider)
                )
                .onChange(of: model.secondaryCredentialBinding(for: provider).wrappedValue) { _, _ in
                    saveCredentialWithErrorHandling(for: provider)
                }
            }
        }

        if let setup = provider.setupLink {
            HStack {
                Button(setup.title) {
                    #if os(macOS)
                    NSWorkspace.shared.open(setup.url)
                    #else
                    UIApplication.shared.open(setup.url)
                    #endif
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private func saveCredentialWithErrorHandling(for provider: DNSProvider) {
        // Clear any previous errors
        model.error = nil

        model.saveCredential(for: provider)

        // Check if there was an error after the operation
        if let error = model.error, !error.isEmpty {
            errorMessage = error
            showingError = true
            model.error = nil // Clear the model error since we're handling it locally
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.accent)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
