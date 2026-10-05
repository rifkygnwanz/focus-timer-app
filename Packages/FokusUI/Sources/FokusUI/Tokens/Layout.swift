import SwiftUI

// MARK: - Spacing

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
}

// MARK: - Radius

public enum Radius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 20
    public static let chip: CGFloat = 100   // kapsul
    public static let card: CGFloat = 16
}

// MARK: - Motion

public enum Motion {
    /// Animasi standar — transisi UI biasa.
    public static let standard = Animation.easeInOut(duration: 0.25)
    /// Animasi cepat — feedback interaktif.
    public static let quick = Animation.easeOut(duration: 0.15)
    /// Animasi lambat — transisi fase yang dramatis.
    public static let slow = Animation.easeInOut(duration: 0.5)
    /// Spring untuk elemen yang muncul.
    public static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)
}
