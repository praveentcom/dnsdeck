# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in DNSDeck, please report it responsibly:

1. **Do not** create a public GitHub issue for security vulnerabilities
2. Email security details to: support@dnsdeck.dev
3. Include as much information as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

DNSDeck handles sensitive DNS provider credentials. We take security seriously:

- **Credential Storage**: All API tokens and keys are stored securely in macOS Keychain
- **Network Security**: All API communications use HTTPS with certificate validation
- **Input Validation**: All user inputs are validated before processing
- **No Logging**: Sensitive credentials are never logged or stored in plain text

## Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Varies by severity and complexity

Thank you for helping keep DNSDeck secure!
