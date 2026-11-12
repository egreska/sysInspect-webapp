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

    /// Brand blue. Light mode is rgb(0, 0.4, 0.8). Dark mode keeps that hue and goes deeper so white titles stay above 4.5:1.
    static var primary: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.34, blue: 0.68, alpha: 1)
                : UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1)
        }
    }

    /// Contrast color on primary (e.g. nav bar title, primary button title)
    static var primaryContrast: UIColor { .white }

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

    /// Needs immediate attention on an InspectionItem.
    static var attention: UIColor { .systemRed }

    /// Monitor on an InspectionItem.
    static var monitor: UIColor { .systemOrange }

    /// Overlay for modals / loading (e.g. dimmed)
    static var overlay: UIColor {
        UIColor.black.withAlphaComponent(0.5)
    }

    /// Space between controls. Tight inside a group, medium between groups, loose between sections.
    static let spacing8: CGFloat = 8
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24

    static let buttonCornerRadius: CGFloat = 8
    static let cardCornerRadius: CGFloat = 12

    /// Long forms stay this wide and centered on iPad.
    static let readableContentWidth: CGFloat = 680

    static func readableWidthConstraints(
        for item: UIView,
        width: NSLayoutDimension,
        centerX: NSLayoutXAxisAnchor,
        leading: NSLayoutXAxisAnchor,
        trailing: NSLayoutXAxisAnchor,
        margin: CGFloat
    ) -> [NSLayoutConstraint] {
        let fill = item.widthAnchor.constraint(equalTo: width, constant: -(margin * 2))
        fill.priority = .defaultHigh
        return [
            item.centerXAnchor.constraint(equalTo: centerX),
            fill,
            item.widthAnchor.constraint(lessThanOrEqualToConstant: readableContentWidth),
            item.leadingAnchor.constraint(greaterThanOrEqualTo: leading, constant: margin),
            item.trailingAnchor.constraint(lessThanOrEqualTo: trailing, constant: -margin)
        ]
    }

    // MARK: - Typography (Dynamic Type)

    static func font(_ style: FontStyle) -> UIFont {
        .preferredFont(forTextStyle: textStyle(for: style))
    }

    /// Bold variant that keeps scaling with Dynamic Type.
    static func fontBold(_ style: FontStyle) -> UIFont {
        scaledFont(for: style, weight: .bold)
    }

    /// Medium weight variant that keeps scaling with Dynamic Type.
    static func fontMedium(_ style: FontStyle) -> UIFont {
        scaledFont(for: style, weight: .medium)
    }

    /// Field name on the inspection form. Subheadline, semibold, scales with Dynamic Type.
    static func fieldLabel() -> UIFont {
        scaledFont(for: .subheadline, weight: .semibold)
    }

    private static func scaledFont(for style: FontStyle, weight: UIFont.Weight) -> UIFont {
        let textStyle = textStyle(for: style)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        let baseSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        let font = UIFont.systemFont(ofSize: baseSize, weight: weight)
        return metrics.scaledFont(for: font)
    }

    private static func textStyle(for style: FontStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title1: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        }
    }

    enum FontStyle {
        case largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption
    }
}
