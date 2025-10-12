//
//  PreferencesView.swift
//  DNSDeck
//
//  Created by Praveen Thirumurugan on 12/10/25.
//

import SwiftUI
import AppKit

struct PreferencesView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingError = false
  @State private var errorMessage = ""
  @State private var showingTestResult = false
  @State private var testResultMessage = ""
  @State private var testResultIsSuccess = false

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
                    .frame(width: 20, height: 20)

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
                  let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
            }
            
            Text("A powerful DNS management tool for macOS that helps you manage your DNS records across multiple providers including Cloudflare, Amazon Route 53 and more.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Features")
              .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
              FeatureRow(icon: "cloud", title: "Multi-Provider Support", description: "Manage DNS records across multiple cloud providers")
              FeatureRow(icon: "lock.shield", title: "Secure Credential Storage", description: "Credentials are stored in your iCloud Keychain")
              FeatureRow(icon: "magnifyingglass", title: "Search & Filter", description: "Quickly find domain zones and DNS records")
              FeatureRow(icon: "plus.circle", title: "Easy Record Management", description: "Add, edit, and delete DNS records with ease")
              FeatureRow(icon: "arrow.clockwise", title: "Real-time Updates", description: "Changes are reflected immediately in your DNS provider")
            }
          }
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Copyright")
              .font(.headline)
            
            Text("© 2025 Praveen Thirumurugan. All rights reserved.")
              .font(.callout)
              .foregroundStyle(.secondary)
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
      Button("OK") { }
    } message: {
      Text(errorMessage)
    }
    .alert(testResultIsSuccess ? "Connection Successful" : "Connection Failed", isPresented: $showingTestResult) {
      Button("OK") { }
    } message: {
      Text(testResultMessage)
    }
  }

  @ViewBuilder
  private func credentialFields(for provider: DNSProvider) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(provider.credentialFieldLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
      
      SecureField(provider.credentialPlaceholder, text: model.credentialBinding(for: provider))
        .textFieldStyle(.roundedBorder)
      
      // Secondary credential field for providers that require it (like Route 53)
      if provider.requiresSecondaryCredential,
         let secondaryLabel = provider.secondaryCredentialFieldLabel,
         let secondaryPlaceholder = provider.secondaryCredentialPlaceholder {
        
        Text(secondaryLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
        
        SecureField(secondaryPlaceholder, text: model.secondaryCredentialBinding(for: provider))
          .textFieldStyle(.roundedBorder)
      }
    }

    HStack {
      Button("Save") {
        saveCredentialWithErrorHandling(for: provider)
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
      .disabled(!isCredentialValid(for: provider))

      if provider == .route53 && model.isProviderConnected(provider) {
        Button("Test Connection") {
          Task {
            await testConnectionWithFeedback()
          }
        }
        .buttonStyle(.bordered)
      }

      if let setup = provider.setupLink {
        Button(setup.title) {
          NSWorkspace.shared.open(setup.url)
        }
        .buttonStyle(.bordered)
      }
    }
  }
  
  private func isCredentialValid(for provider: DNSProvider) -> Bool {
    let primaryCredential = model.credentialBinding(for: provider).wrappedValue
    
    if provider.requiresSecondaryCredential {
      let secondaryCredential = model.secondaryCredentialBinding(for: provider).wrappedValue
      return !primaryCredential.isEmpty && !secondaryCredential.isEmpty
    } else {
      return !primaryCredential.isEmpty
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
  
  private func testConnectionWithFeedback() async {
    do {
      let zones = try await model.route53API.listHostedZones()
      await MainActor.run {
        testResultIsSuccess = true
        testResultMessage = "Successfully connected to Route 53. Found \(zones.count) hosted zone\(zones.count == 1 ? "" : "s")."
        showingTestResult = true
      }
    } catch {
      await MainActor.run {
        testResultIsSuccess = false
        testResultMessage = "Failed to connect to Route 53: \(error.localizedDescription)"
        showingTestResult = true
      }
    }
  }
}

// MARK: - Helper Views

struct FeatureRow: View {
  let icon: String
  let title: String
  let description: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundStyle(.blue)
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
