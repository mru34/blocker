import SwiftUI

extension Color {
    /// The icon's yellow and near-black.
    static let brandYellow = Color(red: 1.0, green: 0.831, blue: 0.231)  // #FFD43B
    static let brandInk = Color(red: 0.078, green: 0.067, blue: 0.059)     // #14110F

    /// App tiles on Home: ink in light mode, a raised dark gray in dark mode (ink would vanish on black).
    static let brandTile = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.173, green: 0.165, blue: 0.149, alpha: 1)     // #2C2A26
        : UIColor(red: 0.078, green: 0.067, blue: 0.059, alpha: 1) })  // #14110F
    /// Text that sits on the yellow, a little softer than ink.
    static let brandYellowSecondary = Color(red: 0.361, green: 0.290, blue: 0.0)  // #5C4A00

    static let brandRed = Color(red: 0.898, green: 0.220, blue: 0.231)  // #E5383B, the "no play" sticker

    /// Home's top section and its type swap in dark mode: yellow on black instead of black on yellow.
    static let heroBackground = adaptive(light: (1.0, 0.831, 0.231), dark: (0, 0, 0))
    static let heroInk = adaptive(light: (0.078, 0.067, 0.059), dark: (1.0, 0.831, 0.231))
    /// Home's apps band: the opposite of the hero.
    static let bandBackground = adaptive(light: (0.078, 0.067, 0.059), dark: (1.0, 0.831, 0.231))
    static let bandInk = adaptive(light: (1.0, 0.831, 0.231), dark: (0.078, 0.067, 0.059))

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    /// Chart bars: today stands out, earlier days recede. Both are at least 3:1 against the card
    /// in light and dark mode.
    static let chartToday = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.831, blue: 0.231, alpha: 1)       // #FFD43B
        : UIColor(red: 0.078, green: 0.067, blue: 0.059, alpha: 1) })  // #14110F
    static let chartPast = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.478, green: 0.463, blue: 0.435, alpha: 1)     // #7A766F
        : UIColor(red: 0.541, green: 0.518, blue: 0.490, alpha: 1) })  // #8A847D
}
