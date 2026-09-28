//
//  PDFTableLayout.swift
//  Systems Inspector
//
//  Resolves PDF table columns and row heights from inspection content.
//

import UIKit

public enum PDFTableColumnKind: Equatable {
    case image
    case date
    case primaryLocation
    case secondaryLocation
    case importance
    case issue
    case comments

    var headerTitle: String {
        switch self {
        case .image: return "Image"
        case .date: return "Date"
        case .primaryLocation: return "Primary\nLocation"
        case .secondaryLocation: return "Secondary\nLocation"
        case .importance: return "Importance"
        case .issue: return "Issue"
        case .comments: return "Comments"
        }
    }
}

public struct PDFItemLayoutInput: Equatable {
    public var photoCount: Int
    public var inspectionDateText: String?
    public var primaryLocation: String
    public var secondaryLocation: String?
    public var importance: Importance
    public var issueText: String
    public var comments: String

    public init(
        photoCount: Int,
        primaryLocation: String,
        secondaryLocation: String?,
        importance: Importance,
        issueText: String,
        comments: String,
        inspectionDateText: String? = nil
    ) {
        self.photoCount = photoCount
        self.inspectionDateText = inspectionDateText
        self.primaryLocation = primaryLocation
        self.secondaryLocation = secondaryLocation
        self.importance = importance
        self.issueText = issueText
        self.comments = comments
    }

    var trimmedSecondary: String? {
        guard let value = secondaryLocation?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    var trimmedComments: String {
        comments.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct PDFResolvedTableLayout: Equatable {
    public struct Column: Equatable {
        public var kind: PDFTableColumnKind
        public var width: CGFloat
    }

    public var columns: [Column]

    public var totalWidth: CGFloat {
        columns.reduce(0) { $0 + $1.width }
    }

    public func width(for kind: PDFTableColumnKind) -> CGFloat? {
        columns.first(where: { $0.kind == kind })?.width
    }

    public static let minRowHeight: CGFloat = 50
    public static let maxRowHeight: CGFloat = 420
    public static let cellInset: CGFloat = 10
    public static let photoGap: CGFloat = 4

    public static var bodyFont: UIFont {
        UIFont(name: "ArialMT", size: 9) ?? UIFont.systemFont(ofSize: 9)
    }

    public static var smallFont: UIFont {
        UIFont(name: "ArialMT", size: 8) ?? UIFont.systemFont(ofSize: 8)
    }

    public static func resolve(
        items: [PDFItemLayoutInput],
        preset: PDFLayoutOptions.ColumnPreset = .standard,
        forceSecondaryLocation: Bool = false,
        includeInspectionDate: Bool = false,
        tableWidth: CGFloat = PDFLayoutOptions.tableContentWidth
    ) -> PDFResolvedTableLayout {
        let includeImage = items.contains { $0.photoCount > 0 }
        let includeSecondary = forceSecondaryLocation || items.contains { $0.trimmedSecondary != nil }
        let includeComments = items.contains { !$0.trimmedComments.isEmpty }
        let maxPhotos = items.map(\.photoCount).max() ?? 0

        var builders: [ColumnBuilder] = []
        if includeImage {
            let preferred = imageWidth(maxPhotos: maxPhotos, preset: preset)
            builders.append(ColumnBuilder(kind: .image, width: preferred, minWidth: 50, flexible: false))
        }

        if includeInspectionDate {
            let dateRange = dateWidthRange(preset: preset)
            let dateTexts = items.map { $0.inspectionDateText ?? "—" }
            let datePreferred = clampedMeasuredWidth(texts: dateTexts, font: bodyFont, range: dateRange)
            builders.append(ColumnBuilder(kind: .date, width: datePreferred, minWidth: dateRange.lowerBound, flexible: false))
        }

        let primaryRange = primaryWidthRange(preset: preset)
        let primaryPreferred = clampedMeasuredWidth(
            texts: items.map(\.primaryLocation),
            font: bodyFont,
            range: primaryRange
        )
        builders.append(ColumnBuilder(kind: .primaryLocation, width: primaryPreferred, minWidth: primaryRange.lowerBound, flexible: false))

        if includeSecondary {
            let secondaryRange = secondaryWidthRange(preset: preset)
            let secondaryTexts = items.map { $0.trimmedSecondary ?? "N/A" }
            let secondaryPreferred = clampedMeasuredWidth(texts: secondaryTexts, font: bodyFont, range: secondaryRange)
            builders.append(ColumnBuilder(kind: .secondaryLocation, width: secondaryPreferred, minWidth: secondaryRange.lowerBound, flexible: false))
        }

        let importanceRange = importanceWidthRange(preset: preset)
        let importancePreferred = clampedMeasuredWidth(
            texts: items.map(\.importance.phrase),
            font: bodyFont,
            range: importanceRange,
            extra: items.contains(where: \.importance.isImmediate) ? 16 : 0
        )
        builders.append(ColumnBuilder(kind: .importance, width: importancePreferred, minWidth: importanceRange.lowerBound, flexible: false))

        let issueMin: CGFloat = 120
        let commentsMin: CGFloat = 100
        builders.append(ColumnBuilder(kind: .issue, width: issueMin, minWidth: issueMin, flexible: true))
        if includeComments {
            builders.append(ColumnBuilder(kind: .comments, width: commentsMin, minWidth: commentsMin, flexible: true))
        }

        assignFlexibleWidths(
            builders: &builders,
            items: items,
            tableWidth: tableWidth,
            includeComments: includeComments
        )
        fitToTableWidth(&builders, tableWidth: tableWidth)

        return PDFResolvedTableLayout(columns: builders.map { Column(kind: $0.kind, width: $0.width) })
    }

    public func rowHeight(for item: PDFItemLayoutInput) -> CGFloat {
        var needed: CGFloat = Self.minRowHeight
        for column in columns {
            let textWidth = max(column.width - Self.cellInset, 8)
            switch column.kind {
            case .image:
                needed = max(needed, Self.photoBlockHeight(photoCount: item.photoCount, columnWidth: column.width))
            case .date:
                needed = max(needed, Self.textHeight(item.inspectionDateText ?? "—", width: textWidth, font: Self.bodyFont) + Self.cellInset)
            case .primaryLocation:
                needed = max(needed, Self.textHeight(item.primaryLocation, width: textWidth, font: Self.bodyFont) + Self.cellInset)
            case .secondaryLocation:
                needed = max(needed, Self.textHeight(item.trimmedSecondary ?? "N/A", width: textWidth, font: Self.bodyFont) + Self.cellInset)
            case .importance:
                needed = max(needed, Self.textHeight(item.importance.phrase, width: textWidth, font: Self.bodyFont) + Self.cellInset)
            case .issue:
                needed = max(needed, Self.textHeight(item.issueText, width: textWidth, font: Self.smallFont) + Self.cellInset)
            case .comments:
                needed = max(needed, Self.textHeight(item.trimmedComments, width: textWidth, font: Self.smallFont) + Self.cellInset)
            }
        }
        return min(max(needed, Self.minRowHeight), Self.maxRowHeight)
    }

    public static func photoRects(count: Int, in bounds: CGRect) -> [CGRect] {
        let photoCount = max(count, 0)
        guard photoCount > 0 else { return [] }
        let cols = photoGridColumns
        let innerWidth = max(bounds.width, 16)
        let thumb = photoThumbSize(innerWidth: innerWidth)
        var rects: [CGRect] = []
        for index in 0..<photoCount {
            let col = index % cols
            let row = index / cols
            let x = bounds.minX + CGFloat(col) * (thumb + photoGap)
            let y = bounds.minY + CGFloat(row) * (thumb + photoGap)
            rects.append(CGRect(x: x, y: y, width: thumb, height: thumb))
        }
        return rects
    }

    // MARK: - Widths

    private struct ColumnBuilder {
        var kind: PDFTableColumnKind
        var width: CGFloat
        var minWidth: CGFloat
        var flexible: Bool
    }

    private static func imageWidth(maxPhotos: Int, preset: PDFLayoutOptions.ColumnPreset) -> CGFloat {
        // Floor at 2 so a 2-up thumb still has usable size when every item has one photo.
        let photos = min(max(maxPhotos, 2), InspectionItem.maxPhotoCount)
        switch (preset, photos) {
        case (.compact, 1): return 50
        case (.compact, 2): return 70
        case (.compact, 3): return 100
        case (.compact, _): return 130
        case (.standard, 1): return 70
        case (.standard, 2): return 110
        case (.standard, 3): return 130
        case (.standard, _): return 150
        case (.wide, 1): return 90
        case (.wide, 2): return 130
        case (.wide, 3): return 150
        case (.wide, _): return 170
        }
    }

    private static func dateWidthRange(preset: PDFLayoutOptions.ColumnPreset) -> ClosedRange<CGFloat> {
        switch preset {
        case .compact: return 70...90
        case .standard: return 80...100
        case .wide: return 90...110
        }
    }

    private static func primaryWidthRange(preset: PDFLayoutOptions.ColumnPreset) -> ClosedRange<CGFloat> {
        switch preset {
        case .compact: return 80...110
        case .standard: return 90...140
        case .wide: return 110...160
        }
    }

    private static func secondaryWidthRange(preset: PDFLayoutOptions.ColumnPreset) -> ClosedRange<CGFloat> {
        switch preset {
        case .compact: return 50...70
        case .standard: return 60...80
        case .wide: return 70...90
        }
    }

    private static func importanceWidthRange(preset: PDFLayoutOptions.ColumnPreset) -> ClosedRange<CGFloat> {
        switch preset {
        case .compact: return 70...90
        case .standard: return 80...100
        case .wide: return 80...110
        }
    }

    private static func clampedMeasuredWidth(
        texts: [String],
        font: UIFont,
        range: ClosedRange<CGFloat>,
        extra: CGFloat = 0
    ) -> CGFloat {
        let longest = texts.max(by: { $0.count < $1.count }) ?? ""
        let measured = (longest as NSString).size(withAttributes: [.font: font]).width + 16 + extra
        return min(max(measured, range.lowerBound), range.upperBound)
    }

    private static func assignFlexibleWidths(
        builders: inout [ColumnBuilder],
        items: [PDFItemLayoutInput],
        tableWidth: CGFloat,
        includeComments: Bool
    ) {
        let fixedWidth = builders.filter { !$0.flexible }.reduce(0) { $0 + $1.width }
        let leftover = tableWidth - fixedWidth
        guard let issueIndex = builders.firstIndex(where: { $0.kind == .issue }) else { return }

        if includeComments, let commentsIndex = builders.firstIndex(where: { $0.kind == .comments }) {
            let issueWeight = max(CGFloat(items.map { $0.issueText.count }.max() ?? 1), 1)
            let commentWeight = max(CGFloat(items.map { $0.trimmedComments.count }.max() ?? 1), 1)
            let totalWeight = issueWeight + commentWeight
            var issueWidth = leftover * issueWeight / totalWeight
            var commentsWidth = leftover - issueWidth
            let issueMin = builders[issueIndex].minWidth
            let commentsMin = builders[commentsIndex].minWidth
            if leftover >= issueMin + commentsMin {
                if issueWidth < issueMin {
                    issueWidth = issueMin
                    commentsWidth = leftover - issueWidth
                }
                if commentsWidth < commentsMin {
                    commentsWidth = commentsMin
                    issueWidth = leftover - commentsWidth
                }
            }
            builders[issueIndex].width = max(issueWidth, 1)
            builders[commentsIndex].width = max(commentsWidth, 1)
        } else {
            builders[issueIndex].width = max(leftover, builders[issueIndex].minWidth)
        }
    }

    private static func fitToTableWidth(_ builders: inout [ColumnBuilder], tableWidth: CGFloat) {
        var sum = builders.reduce(0) { $0 + $1.width }
        if sum > tableWidth {
            var overflow = sum - tableWidth
            for index in builders.indices {
                let slack = builders[index].width - builders[index].minWidth
                let take = min(max(slack, 0), overflow)
                builders[index].width -= take
                overflow -= take
                if overflow <= 0.01 { break }
            }
            if overflow > 0.01 {
                let current = builders.reduce(0) { $0 + $1.width }
                let factor = tableWidth / max(current, 1)
                for index in builders.indices {
                    builders[index].width *= factor
                }
            }
        }
        sum = builders.reduce(0) { $0 + $1.width }
        let drift = tableWidth - sum
        if let lastFlexible = builders.indices.reversed().first(where: { builders[$0].flexible }) {
            builders[lastFlexible].width += drift
        } else if let last = builders.indices.last {
            builders[last].width += drift
        }
    }

    // MARK: - Photo grid / text measure

    private static let photoGridColumns = 2

    private static func photoThumbSize(innerWidth: CGFloat) -> CGFloat {
        max(24, (innerWidth - CGFloat(photoGridColumns - 1) * photoGap) / CGFloat(photoGridColumns))
    }

    private static func photoGrid(photoCount: Int, columnWidth: CGFloat) -> (cols: Int, rows: Int, thumb: CGFloat) {
        let count = max(photoCount, 0)
        guard count > 0 else { return (0, 0, 0) }
        let cols = photoGridColumns
        let rows = Int(ceil(Double(count) / Double(cols)))
        let inner = max(columnWidth - cellInset, 16)
        return (cols, rows, photoThumbSize(innerWidth: inner))
    }

    static func photoBlockHeight(photoCount: Int, columnWidth: CGFloat) -> CGFloat {
        let grid = photoGrid(photoCount: photoCount, columnWidth: columnWidth)
        guard grid.rows > 0 else { return 0 }
        return cellInset + CGFloat(grid.rows) * grid.thumb + CGFloat(max(grid.rows - 1, 0)) * photoGap
    }

    static func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        guard !text.isEmpty, width > 0 else { return 0 }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }
}
