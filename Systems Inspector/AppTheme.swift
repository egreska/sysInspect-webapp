//
//  AppTheme.swift
//  Systems Inspector
//
//  Central design tokens for colors and typography.
//  Supports Dark Mode and Dynamic Type.
//

import UIKit

enum AppTheme {

    // MARK: - Brand colors (adapt for light/dark where needed)

    /// Primary brand color (e.g. nav bar, primary buttons)
    static var primary: UIColor {
        UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
    }

    /// Contrast color on primary (e.g. nav bar title, primary button title)
    static var primaryContrast: UIColor { .white }

    /// Secondary / accent (links, secondary actions)
    static var secondary: UIColor {
        UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
    }

    // MARK: - Semantic colors (system; adapt to Dark Mode)

    static var background: UIColor { .systemBackground }
    static var surface: UIColor { .secondarySystemGroupedBackground }
    static var surfaceElevated: UIColor { .tertiarySystemGroupedBackground }
    static var textPrimary: UIColor { .label }
    static var textSecondary: UIColor { .secondaryLabel }
    static var textTertiary: UIColor { .tertiaryLabel }
    static var separator: UIColor { .separator }
    static var destructive: UIColor { .systemRed }
    static var success: UIColor { .systemGreen }
    static var placeholder: UIColor { .placeholderText }

    /// Overlay for modals / loading (e.g. dimmed)
    static var overlay: UIColor {
        UIColor.black.withAlphaComponent(0.5)
    }

    /// Softer blue for gradient end (nav bar)
    private static var primaryGradientEnd: UIColor {
        UIColor(red: 0.12, green: 0.45, blue: 0.85, alpha: 1.0)
    }

    /// Gradient image for navigation bar (primary → softer blue, left to right).
    /// High contrast preserved for accessibility.
    static func navigationBarGradientImage() -> UIImage? {
        if let cached = cachedNavigationBarGradient { return cached }
        let size = CGSize(width: 400, height: 64)
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let colors = [primary.cgColor, primaryGradientEnd.cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return nil }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.midY),
            end: CGPoint(x: rect.maxX, y: rect.midY),
            options: []
        )
        let image = UIGraphicsGetImageFromCurrentImageContext()
        cachedNavigationBarGradient = image
        return image
    }

    private static var cachedNavigationBarGradient: UIImage?

    // MARK: - Typography (Dynamic Type)

    static func font(_ style: FontStyle) -> UIFont {
        switch style {
        case .largeTitle: return .preferredFont(forTextStyle: .largeTitle)
        case .title1: return .preferredFont(forTextStyle: .title1)
        case .title2: return .preferredFont(forTextStyle: .title2)
        case .title3: return .preferredFont(forTextStyle: .title3)
        case .headline: return .preferredFont(forTextStyle: .headline)
        case .body: return .preferredFont(forTextStyle: .body)
        case .callout: return .preferredFont(forTextStyle: .callout)
        case .subheadline: return .preferredFont(forTextStyle: .subheadline)
        case .footnote: return .preferredFont(forTextStyle: .footnote)
        case .caption: return .preferredFont(forTextStyle: .caption1)
        }
    }

    /// Bold variant of a text style (e.g. for emphasis)
    static func fontBold(_ style: FontStyle) -> UIFont {
        let base = font(style)
        return UIFont.systemFont(ofSize: base.pointSize, weight: .bold)
    }

    /// Medium weight variant
    static func fontMedium(_ style: FontStyle) -> UIFont {
        let base = font(style)
        return UIFont.systemFont(ofSize: base.pointSize, weight: .medium)
    }

    enum FontStyle {
        case largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption
    }
}
