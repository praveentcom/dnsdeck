//
//  PreferencesView.swift
//  DNSDeck
//
//  Created by Praveen Thirumurugan on 12/10/25.
//

import SwiftUI

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
