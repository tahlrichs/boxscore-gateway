//
//  Theme.swift
//  BoxScore
//
//  Created by BoxScore Team
//

import SwiftUI
import UIKit

/// Theme mode options for the app
enum ThemeMode: String, Codable {
    case light  // Dark mode OFF (light theme)
    case dark   // Dark mode ON (dark theme)
    case auto   // Follow system settings
}

/// Centralized theme color definitions for light and dark modes
struct Theme {

    // MARK: - Background Colors

    /// Primary background color (main screen background)
    static func background(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.white
        case .dark:
            return Color(hex: "#1A1A1A")  // Dark background
        @unknown default:
            return Color.white
        }
    }

    /// Card/section background color (slightly elevated surface)
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.white
        case .dark:
            return Color.black  // Pure black card background
        @unknown default:
            return Color.white
        }
    }

    /// Secondary background (for nested sections and main content area)
    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(.systemGroupedBackground)
        case .dark:
            return Color(hex: "#1A1A1A")  // Same as main background
        @unknown default:
            return Color(.systemGroupedBackground)
        }
    }

    // MARK: - Text Colors

    /// Primary text color
    static func text(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        @unknown default:
            return Color.black
        }
    }

    /// Secondary text color (less prominent)
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.gray
        case .dark:
            return Color(hex: "#CCCCCC")  // High-contrast medium grey
        @unknown default:
            return Color.gray
        }
    }

    /// Tertiary text color (least prominent)
    static func tertiaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(.systemGray)
        case .dark:
            return Color(hex: "#999999")  // High-contrast dark grey
        @unknown default:
            return Color(.systemGray)
        }
    }

    // MARK: - Separator & Border Colors

    /// Divider/separator lines
    static func separator(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(.systemGray4)
        case .dark:
            return Color(hex: "#444444")  // High-contrast separator
        @unknown default:
            return Color(.systemGray4)
        }
    }

    // MARK: - System UI Colors (Auto-adapting)

    /// System gray colors (auto-adapt with scheme)
    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)

    // MARK: - Navigation (Always Black)

    /// Navigation bar background (always black in both modes)
    static let navBarBackground = Color.black

    /// Navigation bar text/icons (always white in both modes)
    static let navBarText = Color.white

    // MARK: - Accent Colors (Unchanged)

    /// Yellow accent (stars, indicators)
    static let yellow = Color.yellow

    /// Red (live games, losses)
    static let red = Color.red

    /// Green (wins)
    static let green = Color.green

    /// Blue (profiles, links)
    static let blue = Color.blue

    // MARK: - Fonts

    /// Oswald Bold for headings and scores (high-impact text)
    static func displayFont(size: CGFloat) -> Font {
        .custom("Oswald-Bold", size: size)
    }

    // MARK: - Font Validation (Debug Only)

    #if DEBUG
    /// Validates that custom fonts are properly loaded. Call from app init.
    static func validateFonts() {
        let fontName = "Oswald-Bold"
        if UIFont(name: fontName, size: 12) == nil {
            assertionFailure("Font '\(fontName)' not loaded. Check Info.plist and bundle.")
        }
    }
    #endif
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize a Color from a hex string (e.g., "#1C1C1E")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
