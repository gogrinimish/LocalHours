# Changelog

All notable changes to SimpleTimesheet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-28

### Added

- Initial release
- Time tracking with start/stop functionality
- Timesheet generation (weekly, bi-weekly, monthly)
- Email integration for timesheet submission
- Cross-device sync via cloud storage (iCloud, Google Drive, OneDrive)

#### macOS
- Menu bar app with quick access
- Settings window for configuration
- Native notifications for timesheet reminders

#### iOS
- Tab-based navigation (Timer, History, Timesheet, Settings)
- Home screen widgets (Timer, Summary)
- App Shortcuts for Siri integration
- Long-press quick actions
- Push notifications for reminders

#### Android
- Native app via Skip transpilation
- Home screen widgets
- Notification support
- File-based storage compatible with cloud sync

### Security

- No secrets or API keys in codebase
- All data stored locally or in user-controlled cloud storage
- No analytics or tracking
- No account required
