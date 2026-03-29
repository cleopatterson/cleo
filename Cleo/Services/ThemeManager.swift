import SwiftUI

/// Global theme driven by the user's BusinessProfile.
/// The brand accent colour is user-selectable; all tab accents derive from it.
@Observable
class ThemeManager {
    // User's chosen brand accent (stored as hex in BusinessProfile)
    var brandAccentHex: String = "#4CAE8D"
    var appDisplayName: String = "Cleo"
    var isOnboarded: Bool = false

    var brandAccent: Color {
        Color(hex: brandAccentHex)
    }

    // MARK: - Preset Palettes

    static let presets: [(name: String, hex: String)] = [
        ("Green", "#4CAE8D"),
        ("Emerald", "#34d399"),
        ("Teal", "#2dd4bf"),
        ("Sky", "#38bdf8"),
        ("Indigo", "#818cf8"),
        ("Violet", "#b794f6"),
        ("Rose", "#f472b6"),
        ("Coral", "#fb7185"),
        ("Amber", "#fbbf24"),
    ]

    // MARK: - Tab Colours (all derived from brand accent)

    /// Calendar — uses brand accent directly
    var calendarColor: Color { brandAccent }

    /// Money — warm shift (rotate hue +40°, boost saturation)
    var invoicingColor: Color { brandAccent.hueShifted(by: 0.11, saturationMultiplier: 1.1) }

    /// To Do — complementary shift (rotate hue +180°)
    var todoColor: Color { brandAccent.hueShifted(by: 0.5, saturationMultiplier: 0.9) }

    /// Roadmap — warm-opposite shift (rotate hue +80°)
    var roadmapColor: Color { brandAccent.hueShifted(by: 0.22, saturationMultiplier: 1.0) }

    /// Metrics — cool shift (rotate hue -90°)
    var metricsColor: Color { brandAccent.hueShifted(by: -0.25, saturationMultiplier: 0.85) }

    func color(for tab: TabAccent) -> Color {
        switch tab {
        case .calendar: calendarColor
        case .invoicing: invoicingColor
        case .todo: todoColor
        case .roadmap: roadmapColor
        case .metrics: metricsColor
        }
    }

    // MARK: - Gradient Generators

    func briefingGradient(for tab: TabAccent) -> [Color] {
        let accent = color(for: tab)
        let (r, g, b) = accent.rgbComponents
        return [
            Color(red: r * 0.35, green: g * 0.35, blue: b * 0.35),
            Color(red: r * 0.50, green: g * 0.50, blue: b * 0.50),
            Color(red: r * 0.30, green: g * 0.30, blue: b * 0.30)
        ]
    }

    func heroGradient(for tab: TabAccent) -> [Color] {
        let accent = color(for: tab)
        let (r, g, b) = accent.rgbComponents
        return [
            Color(red: r * 0.40, green: g * 0.40, blue: b * 0.40),
            Color(red: r * 0.55, green: g * 0.55, blue: b * 0.55),
            Color(red: r * 0.30, green: g * 0.30, blue: b * 0.30)
        ]
    }

    // MARK: - Load from profile

    func loadFromProfile(_ profile: BusinessProfile) {
        appDisplayName = profile.appDisplayName.isEmpty ? "Cleo" : profile.appDisplayName
        brandAccentHex = profile.brandAccentHex.isEmpty ? "#4CAE8D" : profile.brandAccentHex
        isOnboarded = profile.isOnboarded
    }

    func saveToProfile(_ profile: BusinessProfile) {
        profile.appDisplayName = appDisplayName
        profile.brandAccentHex = brandAccentHex
        profile.isOnboarded = isOnboarded
        PersistenceController.shared.save()
    }
}

// MARK: - Color Helpers

extension Color {
    var rgbComponents: (r: Double, g: Double, b: Double) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    var hexString: String {
        let (r, g, b) = rgbComponents
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// Shift hue by a fraction (0-1 wraps), optionally adjust saturation.
    func hueShifted(by hueOffset: Double, saturationMultiplier: Double = 1.0) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        var newHue = h + CGFloat(hueOffset)
        if newHue > 1 { newHue -= 1 }
        if newHue < 0 { newHue += 1 }

        let newSat = min(max(s * CGFloat(saturationMultiplier), 0), 1)

        return Color(hue: Double(newHue), saturation: Double(newSat), brightness: Double(b), opacity: Double(a))
    }
}
