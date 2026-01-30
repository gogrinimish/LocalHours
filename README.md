# SimpleTimesheet

[![Build and Test](https://github.com/gogrinimish/SimpleTimesheet/actions/workflows/build.yml/badge.svg)](https://github.com/gogrinimish/SimpleTimesheet/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-blue.svg)](https://github.com/gogrinimish/SimpleTimesheet)

A cross-platform time tracking application for macOS, iOS, and Android. Track your hours, build timesheets, and email them to approvers with one click.

**Learn more:** [SimpleTimesheet website](https://gogrinimish.github.io/SimpleTimesheet/)

## Screenshots

*Add PNGs to `docs/screenshots/` as `macos-menubar.png`, `ios-timer.png`, and `timesheet-preview.png` to show them below.*

| macOS Menu Bar | iOS Timer | Timesheet Preview |
|----------------|-----------|-------------------|
| ![macOS menu bar](docs/screenshots/macos-menubar.png) | ![iOS timer](docs/screenshots/ios-timer.png) | ![Timesheet](docs/screenshots/timesheet-preview.png) |

## Features

### Core Functionality
- **Quick Time Tracking**: Start and stop the clock with a single tap/click
- **Work Descriptions**: Add descriptions when stopping the clock to document what was worked on
- **Timesheet Generation**: Automatically compile tracked time into formatted timesheets
- **Email Integration**: Send timesheets to approvers with customizable email templates
- **Cross-Device Sync**: Store data in cloud folders (iCloud, Google Drive, OneDrive) for seamless sync

### Platform-Specific Features

#### macOS
- Menu bar app for quick access
- Keyboard shortcuts for start/stop
- Native notifications

#### iOS
- Home screen widgets
- Long-press quick actions
- Push notifications for timesheet reminders

#### Android
- Home screen widgets
- App shortcuts for quick actions
- Notifications for timesheet reminders

## Installation

### Prerequisites

#### For Development
- macOS 15+ with Xcode 16+
- [Skip](https://skip.dev) for Android support

```bash
# Install Skip
brew install skiptools/skip/skip

# Verify installation
skip checkup
```

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/gogrinimish/SimpleTimesheet.git
cd SimpleTimesheet
```

2. Open in Xcode:
```bash
open SimpleTimesheet.xcodeproj
```

3. Build and run:
   - For macOS: Select `SimpleTimesheetMac` scheme
   - For iOS: Select `SimpleTimesheet` scheme
   - For Android: Select `SimpleTimesheet` scheme and choose Android device/emulator

### Pre-built Releases

Download the latest release from the [Releases](https://github.com/gogrinimish/SimpleTimesheet/releases) page.

> **Note:** The releases are unsigned. For macOS, you may need to right-click and select "Open" on first launch. For iOS, you'll need to sideload using AltStore, Sideloadly, or a similar tool.

## Configuration

All configuration is stored in JSON files within your chosen storage folder, enabling sync across devices:

```
YourTimesheetFolder/
├── config.json          # App configuration
├── timesheets/          # Generated timesheets
│   ├── 2026-01.json
│   ├── 2026-02.json
│   └── ...
└── time-entries/        # Raw time entry data
    └── entries.json
```

### Configuration Options

| Setting | Description |
|---------|-------------|
| `storageFolder` | Path to the folder for storing timesheets |
| `timezone` | Timezone for timesheet calculations (e.g., "America/New_York") |
| `notificationTime` | Time to send reminder notification (e.g., "17:00") |
| `emailTemplate` | Custom email template for timesheet submissions |
| `approverEmail` | Email address of the timesheet approver |
| `notificationDays` | Days of week to send notifications (e.g., [5] for Friday) |

## Usage

### macOS Menu Bar

1. Click the clock icon in the menu bar
2. Click "Start" to begin tracking
3. When finished, click "Stop" and enter a description
4. At the configured time, you'll receive a notification to send your timesheet
5. Click "Send Timesheet" to email it to your approver

### iOS/Android Widgets

1. Add the SimpleTimesheet widget to your home screen
2. Tap the play button to start tracking
3. Tap the stop button to stop and add a description
4. Use the app for configuration and viewing history

### Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| `⌘⇧S` | Start/Stop clock |
| `⌘⇧T` | Open timesheet |
| `⌘,` | Open preferences |

## Privacy

SimpleTimesheet is designed with privacy in mind:
- **No cloud services required**: All data stays on your devices or your chosen cloud storage
- **No analytics or tracking**: The app doesn't collect any usage data
- **No account required**: Works entirely offline
- **Open source**: Full transparency into how your data is handled

## Feedback & Bugs

Found a bug or have a suggestion? Please open an [issue](https://github.com/gogrinimish/SimpleTimesheet/issues). We use issues for:

- **Bug reports** – describe the problem, steps to reproduce, and your environment (OS, app version).
- **Feature requests** – describe the feature and how you’d use it.
- **General feedback** – ideas, UX improvements, or documentation fixes.

Check [existing issues](https://github.com/gogrinimish/SimpleTimesheet/issues) first to avoid duplicates.

## Collaborators Wanted

SimpleTimesheet is a solo project today. If you’d like to help shape the next set of features, we’re especially interested in collaborators for:

- **Android & Windows apps** – Extend the app to Android (e.g. via [Skip](https://skip.dev)) and Windows (e.g. Swift on Windows or a separate stack). Experience with cross-platform or native mobile/desktop is a plus.
- **Multiple projects / timesheets** – Design and implement support for multiple projects or timesheet “workspaces” (e.g. per client, per contract) with clear data model and UI.

If you’re interested, open an issue with the label `collaborator` or `good first project`, or comment on the relevant [roadmap issues](https://github.com/gogrinimish/SimpleTimesheet/issues).

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a pull request.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `swift test`
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

## Support the Project

If SimpleTimesheet is useful to you, you can support its development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/YOUR_USERNAME)

*Replace `YOUR_USERNAME` with your [Buy Me a Coffee](https://www.buymeacoffee.com) username, or use another link (e.g. Ko-fi, GitHub Sponsors).*

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Skip](https://skip.dev) for cross-platform support
- Icons designed with accessibility in mind
