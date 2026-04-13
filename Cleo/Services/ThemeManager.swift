import SwiftUI

/// Global theme driven by the user's BusinessProfile.
/// The brand accent colour is user-selectable; all tab accents derive from it.
@Observable
class ThemeManager {
    // User's chosen brand accent (stored as hex in BusinessProfile)
    var brandAccentHex: String = "#4CAE8D" {
        didSet { Self.currentBrandAccentHex = brandAccentHex }
    }
    var appDisplayName: String = "Cleo"
    var isOnboarded: Bool = false

    /// Static accessor so TabAccent.color can read the brand accent without a theme instance.
    static var currentBrandAccentHex: String = "#4CAE8D"

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

    // MARK: - Tab Colours (single brand accent across all tabs)

    func color(for tab: TabAccent) -> Color {
        brandAccent
    }

    // MARK: - Gradient Generators
    // Uses HSB brightness adjustment so hue identity is preserved at dark levels.
    // RGB multiplication (the previous approach) collapses all hues toward black
    // making teal, blue, purple indistinguishable at 30-40% brightness.

    func briefingGradient(for tab: TabAccent) -> [Color] {
        [
            brandAccent.atBrightness(0.32),
            brandAccent.atBrightness(0.42),
            brandAccent.atBrightness(0.26)
        ]
    }

    func heroGradient(for tab: TabAccent) -> [Color] {
        [
            brandAccent.atBrightness(0.36),
            brandAccent.atBrightness(0.48),
            brandAccent.atBrightness(0.28)
        ]
    }

    // MARK: - Load from profile

    func loadFromProfile(_ profile: BusinessProfile) {
        appDisplayName = profile.appDisplayName.isEmpty ? "Cleo" : profile.appDisplayName
        let hex = profile.brandAccentHex.isEmpty ? "#4CAE8D" : profile.brandAccentHex
        brandAccentHex = hex
        Self.currentBrandAccentHex = hex
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

    /// Returns the color at a specific HSB brightness, preserving hue and saturation.
    func atBrightness(_ targetBrightness: Double) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: targetBrightness, opacity: Double(a))
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
