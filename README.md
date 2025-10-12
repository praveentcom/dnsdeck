# DNSDeck

A powerful DNS management tool for macOS that helps you manage DNS records across multiple providers including Cloudflare, Amazon Route 53 and more.

## Features

- **Multi-Provider Support** - Manage DNS records across multiple cloud providers
- **Secure Credential Storage** - Credentials are stored in your iCloud Keychain
- **Search & Filter** - Quickly find domain zones and DNS records
- **Easy Record Management** - Add, edit, and delete DNS records with ease
- **Real-time Updates** - Changes are reflected immediately in your DNS provider

## Supported Providers

- Cloudflare
- Amazon Route 53

## Requirements

- macOS 15.6 or later
- Xcode 17.0 or later (for building from source)

## Setup

### Cloudflare
1. Create an API token at [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Required scopes: `Zone:DNS:Edit`, `Zone:DNS:Read`

### Amazon Route 53
1. Create access keys at [AWS IAM Console](https://console.aws.amazon.com/iam/home#/security_credentials)
2. Required permissions: Route53 read/write access

## License

© 2025 Praveen Thirumurugan. All rights reserved.
