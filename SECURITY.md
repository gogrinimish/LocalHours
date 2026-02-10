# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in Local Hours, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email the details to the maintainers (create a private security advisory on GitHub)
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability and determine its severity
- **Fix Timeline**: Critical vulnerabilities will be addressed within 7 days; others within 30 days
- **Disclosure**: We will coordinate with you on public disclosure timing

### Security Best Practices for Users

Since Local Hours stores data locally or in user-controlled cloud storage:

1. **Protect your storage folder**: Ensure your iCloud, Google Drive, or OneDrive account is secured with a strong password and 2FA
2. **Review permissions**: The app only requests permissions necessary for its functionality
3. **Keep updated**: Always use the latest version for security fixes

## Security Architecture

Local Hours is designed with privacy and security in mind:

- **No remote servers**: All data stays on your devices or your chosen cloud storage
- **No analytics**: No usage data is collected or transmitted
- **No accounts**: No authentication servers that could be compromised
- **Open source**: Full transparency into how your data is handled
- **Local processing**: All timesheet generation and email composition happens locally

### Data Storage

- Configuration and time entries are stored as JSON files
- Files are stored in a user-selected folder (can be local or cloud-synced)
- No encryption is applied by the app (relies on OS-level and cloud provider encryption)

### Email Handling

- Emails are composed using the system's `mailto:` handler
- No email credentials are stored or transmitted by the app
- The app never sends emails directly; it opens your default mail client

## Code Signing

The official releases are currently unsigned. This means:

- **macOS**: You may see a Gatekeeper warning; right-click and select "Open" to bypass
- **iOS**: Requires sideloading tools like AltStore or Sideloadly

We recommend building from source if you have security concerns about unsigned binaries.
