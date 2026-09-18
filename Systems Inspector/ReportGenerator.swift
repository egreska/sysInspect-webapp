//
//  ReportGenerator.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import PDFKit

// MARK: - PDF Layout Options
/// Options for PDF report table: include Secondary Location column and density preset.
public struct PDFLayoutOptions {
    public var includeSecondaryLocation: Bool
    /// Compact / Standard / Wide density for content-driven column sizing.
    public var preset: ColumnPreset
    
    public static let tableContentWidth: CGFloat = 11.0 * 72.0 - 36.0 * 2  // 720
    
    public enum ColumnPreset: String, CaseIterable {
        case compact = "Compact"
        case standard = "Standard"
        case wide = "Wide"
    }
    
    public init(includeSecondaryLocation: Bool = false, preset: ColumnPreset = .standard) {
        self.includeSecondaryLocation = includeSecondaryLocation
        self.preset = preset
    }
}

// MARK: - Public Report Data Structure (Move this outside the class)
public struct ReportHeader {
    public var companyName: String
    public var companyAddress: String
    public var companyPhone: String
    public var companyCity: String
    public var companyState: String
    public var companyZipCode: String
    public var inspectorName: String

    public init(
        companyName: String = "",
        companyAddress: String = "",
        companyPhone: String = "",
        companyCity: String = "",
        companyState: String = "",
        companyZipCode: String = "",
        inspectorName: String = "Inspector Name"
    ) {
        self.companyName = companyName
        self.companyAddress = companyAddress
        self.companyPhone = companyPhone
        self.companyCity = companyCity
        self.companyState = companyState
        self.companyZipCode = companyZipCode
        self.inspectorName = inspectorName
    }

    public static func fromUserDefaults(_ defaults: UserDefaults = .standard) -> ReportHeader {
        ReportHeader(
            companyName: defaults.string(forKey: "companyName") ?? "",
            companyAddress: defaults.string(forKey: "companyAddress") ?? "",
            companyPhone: defaults.string(forKey: "companyPhone") ?? "",
            companyCity: defaults.string(forKey: "companyCity") ?? "",
            companyState: defaults.string(forKey: "companyState") ?? "",
            companyZipCode: defaults.string(forKey: "companyZipCode") ?? "",
            inspectorName: defaults.string(forKey: "inspectorName") ?? "Inspector Name"
        )
    }
}

struct ReportRequest {
    enum Format {
        case pdf
        case csv
    }

    var inspections: [ReportInspectionSnapshot]
    var format: Format
    var sortCriteria: SortCriteria?
    var layoutOptions: PDFLayoutOptions
    var dateRangeDescription: String?
    var header: ReportHeader

    init(
        inspections: [ReportInspectionSnapshot],
        format: Format,
        sortCriteria: SortCriteria? = nil,
        layoutOptions: PDFLayoutOptions = PDFLayoutOptions(),
        dateRangeDescription: String? = nil,
        header: ReportHeader
    ) {
        self.inspections = inspections
        self.format = format
        self.sortCriteria = sortCriteria
        self.layoutOptions = layoutOptions
        self.dateRangeDescription = dateRangeDescription
        self.header = header
    }
}

public struct ReportPackage: Equatable {
    public let data: Data
    public let fileName: String
    public let companionData: Data?
    public let companionFileName: String?

    public init(data: Data, fileName: String, companionData: Data? = nil, companionFileName: String? = nil) {
        self.data = data
        self.fileName = fileName
        self.companionData = companionData
        self.companionFileName = companionFileName
    }
}

class ReportGenerator {
    
    // MARK: - Enhanced Layout Constants
    private enum Layout {
        static let pageWidth: CGFloat = 11.0 * 72.0  // 11 inches in points (landscape)
        static let pageHeight: CGFloat = 8.5 * 72.0  // 8.5 inches in points (landscape)
        static let margin: CGFloat = 36.0  // 0.5 inch margins
        static let triangleIconSize: CGFloat = 12.0  // Size for triangle icon
        static let footerHeight: CGFloat = 40.0
        static let customerBlockHeight: CGFloat = 65.0
        static let missingCustomerGap: CGFloat = 50.0
    }

    func export(_ request: ReportRequest) -> ReportExportResult {
        switch request.format {
        case .pdf:
            if request.inspections.isEmpty { return .empty }
            guard CombinedPDFJoinRule.canJoin(request.inspections) else { return .joinFailed }
            let data = generatePDFReport(
                inspections: request.inspections,
                sortCriteria: request.sortCriteria,
                layoutOptions: request.layoutOptions,
                dateRangeDescription: request.dateRangeDescription,
                header: request.header
            )
            return .package(ReportPackage(
                data: data,
                fileName: Self.pdfFileName(for: request.inspections),
                companionData: nil,
                companionFileName: nil
            ))
        case .csv:
            guard !request.inspections.isEmpty else { return .empty }
            guard let package = generateCSVReportWithPhotos(
                inspections: request.inspections,
                sortCriteria: request.sortCriteria,
                dateRangeDescription: request.dateRangeDescription,
                header: request.header
            ) else { return .failed }
            return .package(package)
        }
    }

    private static func pdfFileName(for inspections: [ReportInspectionSnapshot]) -> String {
        let inspection = inspections.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.first
        let dateStr = inspection?.date.map { DateFormatters.format($0, using: DateFormatters.filename) } ?? DateFormatters.format(Date(), using: DateFormatters.filename)
        let sanitized = Self.sanitizedFileNamePart(inspection?.customer?.name ?? "Report")
        return "Inspection_Report_\(sanitized)_\(dateStr).pdf"
    }

    private static func sanitizedFileNamePart(_ value: String) -> String {
        value
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
    
    private func generatePDFReport(inspections: [ReportInspectionSnapshot], sortCriteria: SortCriteria? = nil, layoutOptions: PDFLayoutOptions = PDFLayoutOptions(), dateRangeDescription: String? = nil, header: ReportHeader) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let includeDate = inspections.count > 1
        let items = sortedItems(from: inspections, sortCriteria: sortCriteria)
        let inputs = layoutInputs(for: items, includeDate: includeDate)
        let tableLayout = PDFResolvedTableLayout.resolve(
            items: inputs,
            preset: layoutOptions.preset,
            forceSecondaryLocation: layoutOptions.includeSecondaryLocation,
            includeInspectionDate: includeDate
        )
        let representative = inspections.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }.first
        
        return renderer.pdfData { context in
            let contentPages = contentPageCount(
                inputs: inputs,
                tableLayout: tableLayout,
                inspections: inspections,
                dateRangeDescription: dateRangeDescription,
                header: header
            )
            let hasTOC = contentPages > 1
            let totalPages = hasTOC ? contentPages + 1 : contentPages
            var currentPage = 1
            var currentY: CGFloat = Layout.margin
            
            if hasTOC, let representative {
                context.beginPage()
                currentY = renderTableOfContents(context: context, inspection: representative, inspectionCount: inspections.count, totalContentPages: contentPages, at: currentY)
                currentPage += 1
            }
            
            context.beginPage()
            currentY = Layout.margin
            currentY = renderHeader(context: context, at: currentY, dateRangeDescription: dateRangeDescription, header: header)
            if representative?.customer != nil {
                currentY = renderCustomerInfo(context: context, inspections: inspections, at: currentY, header: header)
            } else {
                currentY += Layout.missingCustomerGap
                print("Warning: Inspection has no associated customer for PDF report.")
            }
            currentY = renderInspectionTableHeader(context: context, at: currentY, tableLayout: tableLayout)
            
            for (row, input) in zip(items, inputs) {
                let rowHeight = tableLayout.rowHeight(for: input)
                let spaceAvailable = Layout.pageHeight - Layout.margin - Layout.footerHeight - currentY
                
                if spaceAvailable < rowHeight {
                    _ = renderFooter(context: context, currentPage: currentPage, totalPages: totalPages, dateRangeDescription: dateRangeDescription)
                    context.beginPage()
                    currentPage += 1
                    currentY = Layout.margin
                    currentY = renderInspectionTableHeader(context: context, at: currentY, tableLayout: tableLayout)
                }
                
                currentY = renderInspectionItemWithInlinePhoto(context: context, item: row.item, input: input, at: currentY, tableLayout: tableLayout)
            }
            
            _ = renderFooter(context: context, currentPage: currentPage, totalPages: totalPages, dateRangeDescription: dateRangeDescription)
        }
    }
    
    private func renderTableOfContents(context: UIGraphicsPDFRendererContext, inspection: ReportInspectionSnapshot, inspectionCount: Int = 1, totalContentPages: Int, at yPosition: CGFloat) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 18) ?? UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let dateStr = inspection.date.map { DateFormatters.format($0, using: DateFormatters.long) } ?? "—"
        let customerName = inspection.customer?.name ?? "Inspection"
        
        "Table of Contents".draw(at: CGPoint(x: Layout.margin, y: yPosition), withAttributes: titleAttrs)
        var y = yPosition + 30
        if inspectionCount > 1 {
            "Combined inspection: \(customerName) (\(inspectionCount) visits)".draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: rowAttrs)
        } else {
            "Inspection: \(customerName) – \(dateStr)".draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: rowAttrs)
        }
        y += 22
        for p in 1...totalContentPages {
            let label = p == 1 ? "Page \(p + 1): Overview and items" : "Page \(p + 1): Items (continued)"
            "\(label)".draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: rowAttrs)
            y += 18
        }
        return y + 20
    }
    
    // MARK: - Rendering Components (Updated with no timestamps and better spacing)
    private func companyLogoLayout(at yPosition: CGFloat) -> (image: UIImage, rect: CGRect)? {
        guard let logoImage = UIImage(named: "company_logo") else { return nil }
        let imageWidth = logoImage.size.width
        let imageHeight = logoImage.size.height
        guard imageWidth.isNormal && imageHeight.isNormal && imageWidth > 0 && imageHeight > 0 else { return nil }
        let maxLogoWidth: CGFloat = 210
        let maxLogoHeight: CGFloat = 105
        let logoAspectRatio = imageWidth / imageHeight
        var logoWidth = maxLogoWidth
        var calculatedLogoHeight = logoWidth / logoAspectRatio
        if calculatedLogoHeight > maxLogoHeight {
            calculatedLogoHeight = maxLogoHeight
            logoWidth = calculatedLogoHeight * logoAspectRatio
        }
        let logoRect = CGRect(x: Layout.margin, y: yPosition, width: logoWidth, height: calculatedLogoHeight)
        return (logoImage, logoRect)
    }

    private func headerBottomY(at yPosition: CGFloat, dateRangeDescription: String?, header: ReportHeader) -> CGFloat {
        let logoHeight = companyLogoLayout(at: yPosition)?.rect.height ?? 0
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 24) ?? UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let titleSize = "Inspection Report".size(withAttributes: titleAttributes)
        let titleY = yPosition + max(0, (logoHeight - titleSize.height) / 2)
        let hasRange = !(dateRangeDescription ?? "").isEmpty
        let titleBottom = titleY + titleSize.height + (hasRange ? 20 : 0)

        var rightSideY = yPosition
        if !header.companyName.isEmpty {
            rightSideY += 18
        }
        if !header.companyAddress.isEmpty {
            rightSideY += 15
            let city = header.companyCity
            let state = header.companyState
            let zipCode = header.companyZipCode
            if !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
                rightSideY += 15
            }
        }
        if !header.companyPhone.isEmpty {
            rightSideY += 15
        }
        let logoBottom = yPosition + logoHeight
        let rightSideBottom = rightSideY + 5
        return max(titleBottom, logoBottom, rightSideBottom) + 20
    }

    private func renderHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat, dateRangeDescription: String? = nil, header: ReportHeader) -> CGFloat {
        var logoHeight: CGFloat = 0
        if let layout = companyLogoLayout(at: yPosition) {
            layout.image.draw(in: layout.rect)
            logoHeight = layout.rect.height
        }
        
        // Title - centered
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 24) ?? UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let title = "Inspection Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (Layout.pageWidth - titleSize.width) / 2
        let titleY = yPosition + max(0, (logoHeight - titleSize.height) / 2)
        title.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttributes)
        
        if let range = dateRangeDescription, !range.isEmpty {
            let rangeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "ArialMT", size: 11) ?? UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]
            let rangeSize = range.size(withAttributes: rangeAttrs)
            let rangeX = (Layout.pageWidth - rangeSize.width) / 2
            range.draw(at: CGPoint(x: rangeX, y: titleY + titleSize.height + 4), withAttributes: rangeAttrs)
        }
        
        // Company info positioned much further right and removed generated timestamp
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        // Company information from the request header snapshot
        let companyName = header.companyName
        let companyAddress = header.companyAddress
        let companyPhone = header.companyPhone
        
        let city = header.companyCity
        let state = header.companyState
        let zipCode = header.companyZipCode
        
        let rightSideX = Layout.pageWidth - Layout.margin - 150
        var rightSideY = yPosition
        
        // Draw company info if available
        if !companyName.isEmpty {
            let companyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Arial-BoldMT", size: 14) ?? UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            companyName.draw(at: CGPoint(x: rightSideX, y: rightSideY), withAttributes: companyAttributes)
            rightSideY += 18
        }
        
        // Format address on two lines
        if !companyAddress.isEmpty {
            // First line: Street address
            companyAddress.draw(at: CGPoint(x: rightSideX, y: rightSideY), withAttributes: dateAttributes)
            rightSideY += 15
            
            // Second line: City, State ZIP
            var cityStateZip = ""
            if !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
                var components: [String] = []
                
                if !city.isEmpty {
                    components.append(city)
                }
                
                if !state.isEmpty && !zipCode.isEmpty {
                    components.append("\(state) \(zipCode)")
                } else if !state.isEmpty {
                    components.append(state)
                } else if !zipCode.isEmpty {
                    components.append(zipCode)
                }
                
                cityStateZip = components.joined(separator: ", ")
            }
            
            if !cityStateZip.isEmpty {
                cityStateZip.draw(at: CGPoint(x: rightSideX, y: rightSideY), withAttributes: dateAttributes)
                rightSideY += 15
            }
        }
        
        // Phone number
        if !companyPhone.isEmpty {
            companyPhone.draw(at: CGPoint(x: rightSideX, y: rightSideY), withAttributes: dateAttributes)
            rightSideY += 15
        }
        
        return headerBottomY(at: yPosition, dateRangeDescription: dateRangeDescription, header: header)
    }

    // MARK: - Page Calculation and Numbering

    /// Same Y-advance as the draw loop. TOC/footer totals come from this walk.
    private func contentPageCount(
        inputs: [PDFItemLayoutInput],
        tableLayout: PDFResolvedTableLayout,
        inspections: [ReportInspectionSnapshot],
        dateRangeDescription: String?,
        header: ReportHeader
    ) -> Int {
        let representative = inspections.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }.first
        var currentY = Layout.margin
        currentY = headerBottomY(at: currentY, dateRangeDescription: dateRangeDescription, header: header)
        if representative?.customer != nil {
            currentY += Layout.customerBlockHeight
        } else {
            currentY += Layout.missingCustomerGap
        }
        currentY += Self.headerRowHeight

        var pages = 1
        let contentBottom = Layout.pageHeight - Layout.margin - Layout.footerHeight
        for input in inputs {
            let rowHeight = tableLayout.rowHeight(for: input)
            if contentBottom - currentY < rowHeight {
                pages += 1
                currentY = Layout.margin + Self.headerRowHeight
            }
            currentY += rowHeight
        }
        return pages
    }

    private func renderFooter(context: UIGraphicsPDFRendererContext, currentPage: Int, totalPages: Int, dateRangeDescription: String? = nil) -> CGFloat {
        let footerY = Layout.pageHeight - Layout.margin - 30
        
        // Small company logo
        if let logoImage = UIImage(named: "company_logo") {
            let imageWidth = logoImage.size.width
            let imageHeight = logoImage.size.height

            // IMPORTANT FIX: Ensure image dimensions are valid and non-zero
            if imageWidth.isNormal && imageHeight.isNormal && imageWidth > 0 && imageHeight > 0 {
                let smallLogoSize: CGFloat = 20
                let logoAspectRatio = imageWidth / imageHeight
                let smallLogoWidth = smallLogoSize * logoAspectRatio
                
                let logoRect = CGRect(
                    x: Layout.margin,
                    y: footerY,
                    width: smallLogoWidth,
                    height: smallLogoSize
                )
                
                logoImage.draw(in: logoRect)
            } else {
                print("Warning: 'company_logo' dimensions are zero, non-finite, or NaN for footer. Skipping logo drawing.")
            }
        }
        
        // Optional date range in center
        if let range = dateRangeDescription, !range.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "ArialMT", size: 9) ?? UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let sz = range.size(withAttributes: attrs)
            range.draw(at: CGPoint(x: (Layout.pageWidth - sz.width) / 2, y: footerY + 5), withAttributes: attrs)
        }
        
        // Page number on the right
        let pageText = "Page \(currentPage) of \(totalPages)"
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let pageSize = pageText.size(withAttributes: pageAttributes)
        pageText.draw(at: CGPoint(x: Layout.pageWidth - Layout.margin - pageSize.width, y: footerY + 5), withAttributes: pageAttributes)
        
        return footerY
    }


    private func renderCustomerInfo(context: UIGraphicsPDFRendererContext, inspections: [ReportInspectionSnapshot], at yPosition: CGFloat, header: ReportHeader) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 16) ?? UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        // Draw section header
        let sectionHeader = "Customer Information"
        sectionHeader.draw(at: CGPoint(x: Layout.margin, y: yPosition), withAttributes: headerAttributes)
        
        // Draw horizontal line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: Layout.margin, y: yPosition + 20))
        linePath.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: yPosition + 20))
        UIColor.lightGray.setStroke()
        linePath.stroke()
        
        // Customer info in a more compact horizontal layout
        let inspection = inspections.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }.first
        let customerName = "Customer: \(inspection?.customer?.name ?? "N/A")"
        let trimmedSite = inspection?.customer?.site?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address: String
        if inspections.count > 1, !trimmedSite.isEmpty {
            address = "Site: \(trimmedSite)"
        } else {
            address = "Address: \(inspection?.customer?.address ?? "N/A")"
        }
        let inspectionDate = Self.customerDateLabel(for: inspections)
        
        // Get current inspector name from settings, not from saved inspection
        let currentInspectorName = header.inspectorName
        let inspector = "Inspector: \(currentInspectorName)"
        
        let infoY = yPosition + 25
        
        customerName.draw(at: CGPoint(x: Layout.margin, y: infoY), withAttributes: attributes)
        address.draw(at: CGPoint(x: Layout.margin + 250, y: infoY), withAttributes: attributes)
        inspectionDate.draw(at: CGPoint(x: Layout.margin, y: infoY + 15), withAttributes: attributes)
        inspector.draw(at: CGPoint(x: Layout.margin + 250, y: infoY + 15), withAttributes: attributes)
        
        return yPosition + Layout.customerBlockHeight
    }
    
    private static let headerRowHeight: CGFloat = 36
    
    private func renderInspectionTableHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat, tableLayout: PDFResolvedTableLayout) -> CGFloat {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 10) ?? UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        var xPosition = Layout.margin
        
        let headerRect = CGRect(x: Layout.margin,
                               y: yPosition - 5,
                               width: Layout.pageWidth - (Layout.margin * 2),
                               height: Self.headerRowHeight)
        UIColor(white: 0.9, alpha: 1.0).setFill()
        context.cgContext.fill(headerRect)
        
        for column in tableLayout.columns {
            let cellRect = CGRect(x: xPosition + 4, y: yPosition - 2, width: column.width - 8, height: Self.headerRowHeight - 6)
            drawCenteredMultiLineText(column.kind.headerTitle, in: cellRect, attributes: headerAttributes)
            xPosition += column.width
        }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Layout.margin, y: yPosition + Self.headerRowHeight - 5))
        path.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: yPosition + Self.headerRowHeight - 5))
        UIColor.black.setStroke()
        path.stroke()
        
        return yPosition + Self.headerRowHeight
    }
    
    private func drawCenteredMultiLineText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .center
        
        var modifiedAttributes = attributes
        modifiedAttributes[.paragraphStyle] = paragraphStyle
        
        let attributedString = NSAttributedString(string: text, attributes: modifiedAttributes)
        attributedString.draw(in: rect)
    }

    // Updated method to draw triangle icon with Arial font
    private func drawTriangleIcon(at point: CGPoint, color: UIColor, size: CGFloat) {
        let trianglePath = UIBezierPath()
        
        // Create equilateral triangle
        let height = size * sqrt(3) / 2
        
        // Top point
        trianglePath.move(to: CGPoint(x: point.x + size/2, y: point.y))
        // Bottom left
        trianglePath.addLine(to: CGPoint(x: point.x, y: point.y + height))
        // Bottom right
        trianglePath.addLine(to: CGPoint(x: point.x + size, y: point.y + height))
        // Close path
        trianglePath.close()
        
        color.setFill()
        trianglePath.fill()
        
        // Add exclamation mark with Arial font
        let exclamationAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: size * 0.6) ?? UIFont.boldSystemFont(ofSize: size * 0.6), // CHANGED to Arial Bold
            .foregroundColor: UIColor.white
        ]
        
        let exclamationMark = "!"
        let exclamationSize = exclamationMark.size(withAttributes: exclamationAttributes)
        let exclamationPoint = CGPoint(
            x: point.x + (size - exclamationSize.width) / 2,
            y: point.y + (height - exclamationSize.height) / 2
        )
        
        exclamationMark.draw(at: exclamationPoint, withAttributes: exclamationAttributes)
    }

    private func renderInspectionItemWithInlinePhoto(context: UIGraphicsPDFRendererContext, item: ReportItemSnapshot, input: PDFItemLayoutInput, at yPosition: CGFloat, tableLayout: PDFResolvedTableLayout) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFResolvedTableLayout.bodyFont,
            .foregroundColor: UIColor.black
        ]
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFResolvedTableLayout.smallFont,
            .foregroundColor: UIColor.black
        ]
        let rowHeight = tableLayout.rowHeight(for: input)
        var xPosition = Layout.margin
        
        for column in tableLayout.columns {
            let textRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: column.width - 10, height: rowHeight - 10)
            switch column.kind {
            case .image:
                drawPhotoGrid(photos: item.photos, in: textRect, attributes: smallAttributes)
            case .date:
                drawMultiLineText(input.inspectionDateText ?? "—", in: textRect, attributes: attributes)
            case .primaryLocation:
                drawMultiLineText(input.primaryLocation, in: textRect, attributes: attributes)
            case .secondaryLocation:
                drawMultiLineText(input.trimmedSecondary ?? "N/A", in: textRect, attributes: attributes)
            case .importance:
                if input.importance == "Needs immediate attention" {
                    let trianglePoint = CGPoint(x: xPosition + 8, y: yPosition + 8)
                    drawTriangleIcon(at: trianglePoint, color: UIColor.red, size: Layout.triangleIconSize)
                    let remaining = CGRect(
                        x: xPosition + 8 + Layout.triangleIconSize + 4,
                        y: yPosition + 5,
                        width: max(column.width - 10 - Layout.triangleIconSize - 8, 12),
                        height: rowHeight - 10
                    )
                    drawMultiLineText(input.importance, in: remaining, attributes: attributes)
                } else {
                    drawMultiLineText(input.importance, in: textRect, attributes: attributes)
                }
            case .issue:
                drawMultiLineText(input.issueText, in: textRect, attributes: smallAttributes)
            case .comments:
                drawWrappedCommentsText(input.trimmedComments, in: textRect, attributes: smallAttributes)
            }
            xPosition += column.width
        }
        
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        var separatorX = Layout.margin
        for column in tableLayout.columns.dropLast() {
            separatorX += column.width
            context.cgContext.move(to: CGPoint(x: separatorX, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: separatorX, y: yPosition + rowHeight))
            context.cgContext.strokePath()
        }
        context.cgContext.move(to: CGPoint(x: Layout.margin, y: yPosition + rowHeight))
        context.cgContext.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: yPosition + rowHeight))
        context.cgContext.strokePath()

        return yPosition + rowHeight
    }

    private func drawPhotoGrid(photos: [Data], in bounds: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let images = photos.compactMap { UIImage(data: $0) }
        guard !images.isEmpty else {
            "No Photo".draw(in: bounds, withAttributes: attributes)
            return
        }
        let rects = PDFResolvedTableLayout.photoRects(count: images.count, in: bounds)
        for (image, slot) in zip(images, rects) {
            let compressed: UIImage
            if let jpegData = image.jpegData(compressionQuality: 0.2), let downsampled = UIImage(data: jpegData) {
                compressed = downsampled
            } else {
                compressed = image
            }
            let photoRect = calculateAspectFitRect(for: compressed, in: slot)
            UIColor.lightGray.setStroke()
            UIBezierPath(rect: photoRect.insetBy(dx: -1, dy: -1)).stroke()
            compressed.draw(in: photoRect)
        }
    }
        
    /// Calculate a rectangle that fits the image within the available bounds while preserving aspect ratio
    private func calculateAspectFitRect(for image: UIImage, in availableBounds: CGRect) -> CGRect {
        let imageSize = image.size
        let availableSize = availableBounds.size
        
        // Handle edge cases
        guard imageSize.width > 0 && imageSize.height > 0 &&
              availableSize.width > 0 && availableSize.height > 0 else {
            print("⚠️ Invalid image or bounds size, using fallback rect")
            return CGRect(x: availableBounds.origin.x, y: availableBounds.origin.y, width: 40, height: 40)
        }
        
        // Calculate aspect ratios
        let imageAspectRatio = imageSize.width / imageSize.height
        let boundsAspectRatio = availableSize.width / availableSize.height
        
        var targetWidth: CGFloat
        var targetHeight: CGFloat
        
        // Determine which dimension should be constrained
        if imageAspectRatio > boundsAspectRatio {
            // Image is wider than bounds - constrain by width
            targetWidth = availableSize.width
            targetHeight = targetWidth / imageAspectRatio
        } else {
            // Image is taller than bounds - constrain by height
            targetHeight = availableSize.height
            targetWidth = targetHeight * imageAspectRatio
        }
        
        // Center the image within the available bounds
        let x = availableBounds.origin.x + (availableSize.width - targetWidth) / 2
        let y = availableBounds.origin.y + (availableSize.height - targetHeight) / 2
        
        let finalRect = CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
        
        // Log aspect ratio information for debugging
        let orientation = imageAspectRatio > 1.0 ? "landscape" : (imageAspectRatio < 1.0 ? "portrait" : "square")
        print("📸 Image: \(Int(imageSize.width))x\(Int(imageSize.height)) (\(orientation)) -> PDF: \(Int(targetWidth))x\(Int(targetHeight))")
        
        return finalRect
    }
    
    // Improved text wrapping specifically for comments column
    private func drawWrappedCommentsText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        
        var modifiedAttributes = attributes
        modifiedAttributes[.paragraphStyle] = paragraphStyle
        
        let attributedString = NSAttributedString(string: text, attributes: modifiedAttributes)
        
        // Use boundingRect to better control text layout within bounds
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // Draw the text, ensuring it stays within the column boundaries
        let drawRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: min(boundingRect.height, rect.height)
        )
        
        attributedString.draw(in: drawRect)
    }
    
    private func drawMultiLineText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        var modifiedAttributes = attributes
        modifiedAttributes[.paragraphStyle] = paragraphStyle
        
        let attributedString = NSAttributedString(string: text, attributes: modifiedAttributes)
        attributedString.draw(in: rect)
    }

    
    // New helper method for text wrapping
    private func drawWrappedText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any], context: UIGraphicsPDFRendererContext) {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(in: rect)
    }
    
    // Updated CSV generation with metadata
    // MARK: - Updated CSV Report Generation with Photos
    private func generateCSVReportWithPhotos(inspections: [ReportInspectionSnapshot], sortCriteria: SortCriteria? = nil, dateRangeDescription: String? = nil, header: ReportHeader) -> ReportPackage? {
        let timeString = DateFormatters.format(Date(), using: DateFormatters.timestamp)
        
        var csvString = "# Systems Inspector Report\n"
        csvString += "# Generated: \(timeString.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: ":"))\n"
        csvString += "# Total Inspections: \(inspections.count)\n"
        if !header.companyName.isEmpty {
            csvString += "# Company: \(header.companyName)\n"
        }
        if !header.inspectorName.isEmpty {
            csvString += "# Inspector: \(header.inspectorName)\n"
        }
        if let rangeDesc = dateRangeDescription {
            csvString += "# Date range: \(rangeDesc)\n"
        }
        csvString += "#\n"
        csvString += "Customer Name,Address,Date,Inspector,Primary Location (Area/Aisle),Secondary Location (Bay/Level),Importance,Issues,Comments,Photo File\n"

        var zipEntries: [(name: String, contents: Data)] = []
            
        for inspection in inspections {
            let customerName = inspection.customer?.name ?? "N/A"
            let customerAddress = inspection.customer?.address ?? "N/A"
            let inspectionDate = inspection.date ?? Date()
            let inspectorName = inspection.inspectorName ?? "N/A"
            let dateString = DateFormatters.format(inspectionDate, using: DateFormatters.dateTime)
            let items = sortedItems(from: [inspection], sortCriteria: sortCriteria).map(\.item)

            for item in items {
                let primaryLocation = item.location.isEmpty ? "N/A" : item.location
                let secondaryLocation = item.bayNumber ?? "N/A"
                let rawImportance = item.importance.isEmpty ? "Monitor" : item.importance
                let importance = rawImportance == "Needs immediate attention" ? "▲ \(rawImportance)" : rawImportance
                let issueStrings = Issue.labels(from: item.issues)
                let issues = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "; ")
                let comments = item.comments ?? ""
                var photoNames: [String] = []
                let itemID = item.id.uuidString
                for (index, photoData) in item.photos.enumerated() {
                    let uniquePhotoName = "photo_\(itemID)_\(index + 1).jpg"
                    zipEntries.append((uniquePhotoName, photoData))
                    photoNames.append(uniquePhotoName)
                }
                let photoFileName = photoNames.joined(separator: "; ")
                let row = [customerName, customerAddress, dateString, inspectorName, primaryLocation, secondaryLocation, importance, issues, comments, photoFileName]
                    .map { Self.escapeCSVField($0) }
                    .joined(separator: ",")
                csvString += row + "\n"
            }
        }

        guard var csvData = csvString.data(using: .utf8) else {
            return nil
        }
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        csvData = Data(bom) + csvData
        
        let zipData = zipEntries.isEmpty ? nil : StoredZipArchive.data(entries: zipEntries)
        let dateStr = inspections.first?.date.map { DateFormatters.format($0, using: DateFormatters.filename) } ?? DateFormatters.format(Date(), using: DateFormatters.filename)
        let customerPart: String
        if inspections.count == 1, let name = inspections.first?.customer?.name, !name.isEmpty {
            let sanitized = Self.sanitizedFileNamePart(name)
            customerPart = sanitized.isEmpty ? "" : "\(sanitized)_"
        } else {
            customerPart = ""
        }
        let csvFileName = "Inspection_Report_\(customerPart)\(dateStr).csv"
        let zipFileName = "Inspection_Photos_\(customerPart)\(dateStr).zip"
        
        return ReportPackage(
            data: csvData,
            fileName: csvFileName,
            companionData: zipData,
            companionFileName: zipData == nil ? nil : zipFileName
        )
    }

    private struct SortedItem {
        let inspection: ReportInspectionSnapshot
        let item: ReportItemSnapshot
    }

    private func sortedItems(from inspections: [ReportInspectionSnapshot], sortCriteria: SortCriteria? = nil) -> [SortedItem] {
        let criteria = sortCriteria ?? .entryOrder
        let ordered = inspections.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        switch criteria {
        case .importance, .primaryLocation, .issue:
            let items = ordered.flatMap { inspection in
                inspection.items.map { SortedItem(inspection: inspection, item: $0) }
            }
            return sortItems(items, sortCriteria: criteria)
        case .entryOrder, .date, .customer, .inspectionStatus:
            return ordered.flatMap { inspection in
                sortItems(inspection.items.map { SortedItem(inspection: inspection, item: $0) }, sortCriteria: .entryOrder)
            }
        }
    }

    private func layoutInputs(for items: [SortedItem], includeDate: Bool) -> [PDFItemLayoutInput] {
        items.map { row in
            let dateText: String?
            if includeDate {
                dateText = row.inspection.date.map { DateFormatters.format($0, using: DateFormatters.medium) } ?? "—"
            } else {
                dateText = nil
            }
            let issueStrings = Issue.labels(from: row.item.issues)
            return PDFItemLayoutInput(
                photoCount: row.item.photos.count,
                primaryLocation: row.item.location.isEmpty ? "N/A" : row.item.location,
                secondaryLocation: row.item.bayNumber,
                importance: row.item.importance.isEmpty ? "Monitor" : row.item.importance,
                issueText: issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "\n"),
                comments: row.item.comments ?? "",
                inspectionDateText: dateText
            )
        }
    }

    private static func customerDateLabel(for inspections: [ReportInspectionSnapshot]) -> String {
        let dates = inspections.compactMap(\.date).sorted()
        guard let first = dates.first else { return "Date: —" }
        if let last = dates.last, !Calendar.current.isDate(first, inSameDayAs: last) {
            return "Dates: \(DateFormatters.format(first, using: DateFormatters.long)) – \(DateFormatters.format(last, using: DateFormatters.long))"
        }
        return "Date: \(DateFormatters.format(first, using: DateFormatters.long))"
    }

    private func sortItems(_ items: [SortedItem], sortCriteria: SortCriteria) -> [SortedItem] {
        switch sortCriteria {
        case .importance:
            return items.sorted { lhs, rhs in
                let importance1 = lhs.item.importance.isEmpty ? "Monitor" : lhs.item.importance
                let importance2 = rhs.item.importance.isEmpty ? "Monitor" : rhs.item.importance
                if importance1 == "Needs immediate attention" && importance2 == "Monitor" {
                    return true
                } else if importance1 == "Monitor" && importance2 == "Needs immediate attention" {
                    return false
                }
                return lhs.item.location < rhs.item.location
            }
        case .primaryLocation:
            return items.sorted { lhs, rhs in
                let result = lhs.item.location.compare(rhs.item.location, options: [.numeric, .caseInsensitive])
                if result == .orderedSame {
                    let bay1 = lhs.item.bayNumber ?? ""
                    let bay2 = rhs.item.bayNumber ?? ""
                    return bay1.compare(bay2, options: [.numeric, .caseInsensitive]) == .orderedAscending
                }
                return result == .orderedAscending
            }
        case .issue:
            return items.sorted { lhs, rhs in
                let issue1 = Issue.primaryParentLabel(from: lhs.item.issues)
                let issue2 = Issue.primaryParentLabel(from: rhs.item.issues)
                if issue1 == issue2 {
                    return lhs.item.location < rhs.item.location
                }
                return issue1 < issue2
            }
        case .entryOrder, .date, .customer, .inspectionStatus:
            return items.sorted { $0.item.sequenceNumber < $1.item.sequenceNumber }
        }
    }

    /// Escapes a CSV field: wraps in quotes and doubles internal quotes (RFC 4180).
    private static func escapeCSVField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
}
