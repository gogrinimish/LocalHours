# Local Hours Android

This directory contains the Android-specific configuration and resources for Local Hours.

## Building for Android

### Prerequisites

1. Install Skip:
   ```bash
   brew install skiptools/skip/skip
   ```

2. Verify installation:
   ```bash
   skip checkup
   ```

3. Ensure Android SDK is installed (Skip handles this automatically)

### Building

From the project root:

```bash
# Build for Android
skip build --android

# Run on Android emulator
skip run --android

# Generate APK
skip export --android
```

### Project Structure

When you build for Android, Skip generates:

```
Android/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── kotlin/          # Transpiled Kotlin code
│   │       ├── res/             # Android resources
│   │       └── AndroidManifest.xml
│   └── build.gradle.kts
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

### Configuration

Android-specific configuration is in `skip.yml` at the project root.

### Widgets

Android widgets use Jetpack Glance, which Skip maps from SwiftUI's WidgetKit APIs where possible. Some widget functionality may require Android-specific implementation.

### Notifications

Android notifications require notification channels. These are set up automatically by Skip based on the notification configuration in the Swift code.

### File Storage

For cross-device sync on Android:
- **Google Drive**: Use the Google Drive folder path
- **OneDrive**: Use the OneDrive folder path  
- **Manual sync**: Use any folder accessible to file sync apps

### Permissions

The app requests these permissions:
- `POST_NOTIFICATIONS` - For timesheet reminders
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` - For cloud storage folder access
- `SCHEDULE_EXACT_ALARM` - For precise notification timing
