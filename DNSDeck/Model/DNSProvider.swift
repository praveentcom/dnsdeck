//
//  DNSProvider.swift
//  DNSDeck
//
//  Created by ChatGPT on 12/10/25.
//

import Foundation

enum DNSProvider: String, CaseIterable, Identifiable {
    case cloudflare
    case route53

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .cloudflare: return "Cloudflare"
        case .route53: return "Amazon Route 53"
        }
    }

    var displayName: String {
        switch self {
        case .cloudflare: return "Cloudflare"
        case .route53: return "Amazon Route 53"
        }
    }

    var description: String {
        switch self {
        case .cloudflare:
            return "Scopes required: Zone:DNS:Edit, Zone:DNS:Read."
        case .route53:
            return "Requires AWS Access Key ID and Secret Access Key with Route53 permissions."
        }
    }

    var credentialFieldLabel: String {
        switch self {
        case .cloudflare: return "API Token"
        case .route53: return "Access Key ID"
        }
    }

    var credentialPlaceholder: String {
        switch self {
        case .cloudflare: return "Paste token"
        case .route53: return "AKIA..."
        }
    }

    var credentialVisiblePlaceholder: String {
        "\(credentialFieldLabel) (visible)"
    }

    var setupLink: (title: String, url: URL)? {
        switch self {
        case .cloudflare:
            return (
                "Create an API token ↗",
                URL(string: "https://dash.cloudflare.com/profile/api-tokens")!
            )
        case .route53:
            return (
                "Create access keys ↗",
                URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!
            )
        }
    }

    var symbolName: String {
        switch self {
        case .cloudflare: return "cloud"
        case .route53: return "server.rack"
        }
    }
    
    // Route 53 requires two credentials
    var requiresSecondaryCredential: Bool {
        switch self {
        case .cloudflare: return false
        case .route53: return true
        }
    }
    
    var secondaryCredentialFieldLabel: String? {
        switch self {
        case .cloudflare: return nil
        case .route53: return "Secret Access Key"
        }
    }
    
    var secondaryCredentialPlaceholder: String? {
        switch self {
        case .cloudflare: return nil
        case .route53: return "Secret key"
        }
    }
}

