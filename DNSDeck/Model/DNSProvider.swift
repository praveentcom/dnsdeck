
import Foundation

enum DNSProvider: String, CaseIterable, Identifiable {
    case cloudflare
    case route53

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .cloudflare: "Cloudflare"
        case .route53: "Amazon Route 53"
        }
    }

    var displayName: String {
        switch self {
        case .cloudflare: "Cloudflare"
        case .route53: "Amazon Route 53"
        }
    }

    var description: String {
        switch self {
        case .cloudflare:
            "Scopes required: Zone:DNS:Edit, Zone:DNS:Read."
        case .route53:
            "Requires AWS Access Key ID and Secret Access Key with Route53 permissions."
        }
    }

    var credentialFieldLabel: String {
        switch self {
        case .cloudflare: "API Token"
        case .route53: "Access Key ID"
        }
    }

    var credentialPlaceholder: String {
        switch self {
        case .cloudflare: "Paste token"
        case .route53: "AKIA..."
        }
    }

    var credentialVisiblePlaceholder: String {
        "\(credentialFieldLabel) (visible)"
    }

    var setupLink: (title: String, url: URL)? {
        switch self {
        case .cloudflare:
            (
                "Create an API token ↗",
                URL(string: "https://dash.cloudflare.com/profile/api-tokens")!
            )
        case .route53:
            (
                "Create access keys ↗",
                URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!
            )
        }
    }

    var symbolName: String {
        switch self {
        case .cloudflare: "cloud"
        case .route53: "server.rack"
        }
    }

    // Route 53 requires two credentials
    var requiresSecondaryCredential: Bool {
        switch self {
        case .cloudflare: false
        case .route53: true
        }
    }

    var secondaryCredentialFieldLabel: String? {
        switch self {
        case .cloudflare: nil
        case .route53: "Secret Access Key"
        }
    }

    var secondaryCredentialPlaceholder: String? {
        switch self {
        case .cloudflare: nil
        case .route53: "Secret key"
        }
    }
}
