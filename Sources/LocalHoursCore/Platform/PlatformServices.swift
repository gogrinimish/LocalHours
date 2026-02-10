import Foundation
#if canImport(SkipFoundation)
import SkipFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Platform-specific service implementations
/// Uses compile-time conditionals for Skip/Android compatibility

// MARK: - Platform Detection

public enum Platform {
    case iOS
    case macOS
    case android
    
    public static var current: Platform {
        #if SKIP
        return .android
        #elseif os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #else
        return .iOS
        #endif
    }
    
    /// Display name for the platform (renamed from 'name' to avoid Kotlin conflict)
    public var displayName: String {
        switch self {
        case .iOS: return "iOS"
        case .macOS: return "macOS"
        case .android: return "Android"
        }
    }
}

// MARK: - Platform-Specific Storage Paths

public struct PlatformPaths {
    #if !SKIP
    /// Get the default documents directory path
    public static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Get the default app support directory
    public static var appSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
    #endif
    
    /// Check if a path is accessible for cloud storage
    public static func isCloudStoragePath(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        
        // Check for common cloud storage paths
        if lowercased.contains("icloud") ||
           lowercased.contains("google") && lowercased.contains("drive") ||
           lowercased.contains("onedrive") ||
           lowercased.contains("dropbox") {
            return true
        }
        
        return false
    }
}

// MARK: - Platform-Specific Haptics

#if !SKIP
public struct PlatformHaptics {
    /// Trigger a light impact haptic
    public static func lightImpact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        // macOS doesn't have equivalent haptics
    }
    
    /// Trigger a success haptic
    public static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        // macOS doesn't have equivalent haptics
    }
}

// MARK: - Platform-Specific Share

public struct PlatformShare {
    /// Share text content
    public static func shareText(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
        // iOS sharing is handled through SwiftUI's ShareLink
    }
}
#endif
