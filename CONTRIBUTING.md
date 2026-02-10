# Contributing to Local Hours

Thank you for your interest in contributing to Local Hours! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/gogrinimish/LocalHours/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Platform (macOS, iOS, Android) and version
   - Screenshots if applicable

### Suggesting Features

1. Check existing issues and discussions
2. Create a new issue with the "feature request" label
3. Describe the feature and its use case
4. Be open to discussion about implementation

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes following our coding standards
4. Write or update tests as needed
5. Ensure all tests pass
6. Commit with clear messages
7. Push to your fork
8. Open a Pull Request

## Development Setup

### Prerequisites

- macOS 15+ with Xcode 16+
- [Skip](https://skip.dev) for Android development

```bash
# Install Skip
brew install skiptools/skip/skip

# Verify installation
skip checkup
```

### Building

```bash
# Clone the repository
git clone https://github.com/gogrinimish/LocalHours.git
cd LocalHours

# Open in Xcode
open LocalHours.xcodeproj

# Or build from command line
xcodebuild -scheme LocalHours -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### Building for Android

```bash
# Build for Android
skip build --android

# Run on emulator
skip run --android
```

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and small
- Add documentation comments for public APIs

### Code Organization

```
Sources/LocalHoursCore/
├── Models/          # Data models
├── Services/        # Business logic
├── ViewModels/      # UI state management
├── Views/           # SwiftUI views
└── Platform/        # Platform-specific code
```

### Skip Compatibility

When writing shared code:
- Avoid unsupported Swift features (see [Skip documentation](https://skip.tools/docs/swiftsupport))
- Use `#if SKIP` for Android-specific code
- Test on both iOS and Android

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add weekly summary view
fix: Correct timezone calculation in timesheet
docs: Update installation instructions
refactor: Simplify storage service
test: Add unit tests for TimeEntry
```

## Testing

### Unit Tests

- Write tests for all business logic
- Use descriptive test names
- Cover edge cases

### UI Testing

- Test critical user flows
- Verify accessibility
- Test on multiple device sizes

## Documentation

- Update README.md for user-facing changes
- Add inline documentation for complex code
- Update CONTRIBUTING.md if processes change

## Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Create a release branch
4. Run full test suite
5. Create GitHub release with notes
6. Build and upload artifacts

## Getting Help

- Open a [Discussion](https://github.com/gogrinimish/LocalHours/discussions)
- Check existing documentation
- Review closed issues

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
