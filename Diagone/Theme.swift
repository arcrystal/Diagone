import SwiftUI

/// Defines colour tokens used throughout the application. Centralising the palette
/// makes it easy to adjust appearance for light and dark modes or customise
/// themes via a configuration file in the future. Colours are exposed as
/// static computed properties on `Color` for convenience.
extension Color {
    /// Background colour for individual board cells. A subtle off‑white in light
    /// mode and a dark grey in dark mode to retain appropriate contrast.
    static var boardCell: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0) : UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1.0)
        })
    }
    /// Colour for the grid lines separating cells. Uses a soft grey in light
    /// mode and a lighter grey in dark mode.
    static var gridLine: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.32, blue: 0.35, alpha: 1.0) : UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1.0)
        })
    }
    /// Colour for the main diagonal cells. Based on the New York Times blue
    /// (#1E5AA7) described in the problem statement. Slightly lighter in dark
    /// mode to aid contrast.
    static var mainDiagonal: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.28, green: 0.6, blue: 0.8, alpha: 0.7) : UIColor(red: 0.12, green: 0.35, blue: 0.65, alpha: 0.7)
        })
    }
    /// Colour used to tint rows during the win animation. A warm yellow
    /// (#F9C23C) reminiscent of the NYT accent. Slightly desaturated in dark
    /// mode.
    static var accent: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.88, green: 0.70, blue: 0.26, alpha: 1.0) : UIColor(red: 0.97, green: 0.76, blue: 0.24, alpha: 1.0)
        })
    }
    /// Colour used to highlight valid drop targets while dragging. Uses the
    /// accent colour at reduced opacity.
    static var hoverHighlight: Color {
        accent.opacity(0.4)
    }
    /// Colour for letters displayed on the board. Black in light mode and
    /// off‑white in dark mode.
    static var letter: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) : UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        })
    }
}
