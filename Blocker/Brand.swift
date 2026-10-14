import SwiftUI

extension Color {
    /// The icon's yellow and near-black.
    static let brandYellow = Color(red: 1.0, green: 0.831, blue: 0.231)  // #FFD43B
    static let brandInk = Color(red: 0.078, green: 0.067, blue: 0.059)     // #14110F

    /// Chart bars: today stands out, earlier days recede. Both are at least 3:1 against the card
    /// in light and dark mode.
    static let chartToday = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.831, blue: 0.231, alpha: 1)       // #FFD43B
        : UIColor(red: 0.078, green: 0.067, blue: 0.059, alpha: 1) })  // #14110F
    static let chartPast = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.478, green: 0.463, blue: 0.435, alpha: 1)     // #7A766F
        : UIColor(red: 0.541, green: 0.518, blue: 0.490, alpha: 1) })  // #8A847D
}
