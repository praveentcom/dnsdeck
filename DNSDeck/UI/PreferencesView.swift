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
            HStack(spacing: 12) {
              Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
              
              VStack(alignment: .leading, spacing: 4) {
                Text("DNSDeck")
                  .font(.title2.weight(.semibold))
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                  Text("Version \(version) (\(build))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
              }
            }
            
            Text("A powerful DNS management tool for macOS that helps you manage your DNS records across multiple providers including Cloudflare and Amazon Route 53.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Features")
              .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
              FeatureRow(icon: "cloud", title: "Multi-Provider Support", description: "Manage DNS records across Cloudflare and Amazon Route 53")
              FeatureRow(icon: "lock.shield", title: "Secure Credential Storage", description: "Your API keys are safely stored in macOS Keychain")
              FeatureRow(icon: "magnifyingglass", title: "Search & Filter", description: "Quickly find domains and DNS records")
              FeatureRow(icon: "plus.circle", title: "Easy Record Management", description: "Add, edit, and delete DNS records with ease")
              FeatureRow(icon: "arrow.clockwise", title: "Real-time Updates", description: "Changes are reflected immediately in your DNS provider")
            }
          }
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Copyright")
              .font(.headline)
            
            Text("© 2024 DNSDeck. All rights reserved.")
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
      
      // Support Tab
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
              Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
              
              VStack(alignment: .leading, spacing: 4) {
                Text("Get Support")
                  .font(.title2.weight(.semibold))
                
                Text("Need help? We're here to assist you.")
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
            }
          }
          
          VStack(alignment: .leading, spacing: 16) {
            SupportTile(
              icon: "envelope.fill",
              title: "Email Support",
              description: "Get help with any questions or issues",
              action: "Contact Support",
              actionColor: .blue
            ) {
              let subject = "DNSDeck Support Request"
              let body = """
              
              
              ---
              App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
              Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
              macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
              """
              
              if let emailURL = URL(string: "mailto:support@dnsdeck.dev?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                NSWorkspace.shared.open(emailURL)
              }
            }
            
            SupportTile(
              icon: "star.fill",
              title: "Rate DNSDeck",
              description: "Enjoying DNSDeck? Leave us a review on the App Store",
              action: "Rate App",
              actionColor: .orange
            ) {
              // This would open the App Store page when the app is published
              if let appStoreURL = URL(string: "macappstore://apps.apple.com/app/dnsdeck/id123456789") {
                NSWorkspace.shared.open(appStoreURL)
              }
            }
            
            SupportTile(
              icon: "globe",
              title: "Website",
              description: "Visit our website for more information and updates",
              action: "Visit Website",
              actionColor: .green
            ) {
              if let websiteURL = URL(string: "https://dnsdeck.dev") {
                NSWorkspace.shared.open(websiteURL)
              }
            }
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .tabItem {
        Label("Support", systemImage: "questionmark.circle")
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
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundStyle(.blue)
        .frame(width: 20)
      
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

struct SupportTile: View {
  let icon: String
  let title: String
  let description: String
  let action: String
  let actionColor: Color
  let onAction: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(actionColor)
          .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.callout.weight(.medium))
          
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Spacer()
      }
      
      HStack {
        Spacer()
        Button(action) {
          onAction()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(12)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
