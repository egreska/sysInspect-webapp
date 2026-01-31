//
//  ReportGenerator.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import PDFKit
import CoreData
import Compression // This import is likely only needed if you're using ZIPFoundation or similar, which was noted as a placeholder. You might be able to remove it if not actively zipping.

// MARK: - Public Report Data Structure (Move this outside the class)
public struct ReportPackage {
    public let csvData: Data
    public let zipData: Data?
    public let csvFileName: String
    public let zipFileName: String
    
    public init(csvData: Data, zipData: Data?, csvFileName: String, zipFileName: String) {
        self.csvData = csvData
        self.zipData = zipData
        self.csvFileName = csvFileName
        self.zipFileName = zipFileName
    }
}

class ReportGenerator {
    
    // MARK: - Enhanced Layout Constants
    private enum Layout {
        static let pageWidth: CGFloat = 11.0 * 72.0  // 11 inches in points (landscape)
        static let pageHeight: CGFloat = 8.5 * 72.0  // 8.5 inches in points (landscape)
        static let margin: CGFloat = 36.0  // 0.5 inch margins
        static let headerHeight: CGFloat = 100.0  // Increased to accommodate logo
        static let inlinePhotoSize: CGFloat = 60.0  // Smaller photos for inline display
        static let lineSpacing: CGFloat = 20.0
        static let rowHeight: CGFloat = 90.0  // Increased from 70 to 90 to accommodate multiple issue lines
        static let triangleIconSize: CGFloat = 12.0  // Size for triangle icon
        static let footerHeight: CGFloat = 40.0  // NEW: Footer height
    }
    
    // MARK: - Report Format Options
    enum ReportFormat {
        case pdf
        case csv
        case print
    }
    
    // Updated main report generation method with proper page tracking
    func generatePDFReport(inspection: Inspection, sortCriteria: SortCriteria? = nil, format: ReportFormat = .pdf) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            // Calculate total pages upfront
            let totalPages = calculateTotalPages(for: inspection)
            var currentPage = 1
            var currentY: CGFloat = Layout.margin
            
            // First Page
            context.beginPage()
            currentY = renderHeader(context: context, at: currentY)
            if inspection.customer != nil {
                currentY = renderCustomerInfo(context: context, inspection: inspection, at: currentY)
            } else {
                currentY += 50
                print("Warning: Inspection has no associated customer for PDF report.")
            }
            currentY = renderInspectionTableHeader(context: context, at: currentY)
            
            // Get sorted inspection items
            let items = getSortedInspectionItems(from: inspection, sortCriteria: sortCriteria)
            
            // Render each inspection item with inline photos
            for item in items {
                // Calculate if this item would fit on current page
                let spaceNeeded = Layout.rowHeight
                let spaceAvailable = Layout.pageHeight - Layout.margin - Layout.footerHeight - currentY // Adjusted for footer height
                
                // If item won't fit, start new page
                if spaceAvailable < spaceNeeded {
                    // Render footer before new page
                    _ = renderFooter(context: context, currentPage: currentPage, totalPages: totalPages)
                    
                    // Start new page
                    context.beginPage()
                    currentPage += 1
                    currentY = Layout.margin
                    currentY = renderInspectionTableHeader(context: context, at: currentY)
                }
                
                currentY = renderInspectionItemWithInlinePhoto(context: context, item: item, at: currentY)
            }
            
            // Render footer on the last page
            _ = renderFooter(context: context, currentPage: currentPage, totalPages: totalPages)
        }
    }
    
    // MARK: - Rendering Components (Updated with no timestamps and better spacing)
    private func renderHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat) -> CGFloat {
        // Company logo - positioned on the left (50% larger)
        var logoHeight: CGFloat = 0
        if let logoImage = UIImage(named: "company_logo") {
            let imageWidth = logoImage.size.width
            let imageHeight = logoImage.size.height

            // IMPORTANT FIX: Ensure image dimensions are valid and non-zero to prevent NaN/Infinity
            if imageWidth.isNormal && imageHeight.isNormal && imageWidth > 0 && imageHeight > 0 {
                let maxLogoWidth: CGFloat = 210  // Increased from 120 (50% larger)
                let maxLogoHeight: CGFloat = 105   // Increased from 60 (50% larger)
                
                let logoAspectRatio = imageWidth / imageHeight
                var logoWidth = maxLogoWidth
                var calculatedLogoHeight = logoWidth / logoAspectRatio
                
                // If height is too large, constrain by height instead
                if calculatedLogoHeight > maxLogoHeight {
                    calculatedLogoHeight = maxLogoHeight
                    logoWidth = calculatedLogoHeight * logoAspectRatio
                }
                
                let logoRect = CGRect(
                    x: Layout.margin,
                    y: yPosition,
                    width: logoWidth,
                    height: calculatedLogoHeight
                )
                
                logoImage.draw(in: logoRect)
                logoHeight = calculatedLogoHeight
            } else {
                print("Warning: 'company_logo' dimensions are zero, non-finite, or NaN. Skipping logo drawing in header.")
                // logoHeight remains 0, which is safe.
            }
        } else {
            print("Warning: 'company_logo' asset not found. Skipping logo drawing in header.")
            // logoHeight remains 0, which is safe.
        }
        
        // Title - centered
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 24) ?? UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let title = "Inspection Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (Layout.pageWidth - titleSize.width) / 2
        // Ensure titleY calculation is robust (logoHeight is guaranteed to be a valid number here)
        let titleY = yPosition + max(0, (logoHeight - titleSize.height) / 2) // Center vertically with logo
        
        title.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttributes)
        
        // Company info positioned much further right and removed generated timestamp
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        // Company information from UserDefaults
        let companyName = UserDefaults.standard.string(forKey: "companyName") ?? ""
        let companyAddress = UserDefaults.standard.string(forKey: "companyAddress") ?? ""
        let companyPhone = UserDefaults.standard.string(forKey: "companyPhone") ?? ""
        
        // Parse address components for proper formatting
        let city = UserDefaults.standard.string(forKey: "companyCity") ?? ""
        let state = UserDefaults.standard.string(forKey: "companyState") ?? ""
        let zipCode = UserDefaults.standard.string(forKey: "companyZipCode") ?? ""
        
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
        
        // Return the maximum height used
        let titleBottom = titleY + titleSize.height
        let logoBottom = yPosition + logoHeight
        let rightSideBottom = rightSideY + 5 // Reduced padding since no timestamp
        
        return max(titleBottom, logoBottom, rightSideBottom) + 20
    }

    // MARK: - Page Calculation and Numbering

    private func calculateTotalPages(for inspection: Inspection) -> Int {
        // Calculate available space per page
        let headerHeight = Layout.headerHeight + 65 + 25 // Header + customer info + table header
        let footerHeight: CGFloat = Layout.footerHeight // Space reserved for footer
        let availableHeight = Layout.pageHeight - (Layout.margin * 2) - headerHeight - footerHeight
        _ = Int(availableHeight / Layout.rowHeight) // Use _ for unused variable
        
        // Get total number of inspection items
        let totalItems = (inspection.items?.count ?? 0)
        
        if totalItems == 0 {
            return 1 // At least one page even if no items
        }
        
        // First page can fit items after header
        let firstPageRows = Int((Layout.pageHeight - Layout.margin - headerHeight - footerHeight) / Layout.rowHeight)
        
        if totalItems <= firstPageRows {
            return 1
        }
        
        // Additional pages (no header, just table header)
        let additionalItems = totalItems - firstPageRows
        let tableHeaderHeight: CGFloat = 25
        let additionalPageAvailableHeight = Layout.pageHeight - (Layout.margin * 2) - tableHeaderHeight - footerHeight
        let additionalPageRows = Int(additionalPageAvailableHeight / Layout.rowHeight)
        
        let additionalPages = (additionalItems + additionalPageRows - 1) / additionalPageRows // Ceiling division
        
        return 1 + additionalPages
    }

    private func renderFooter(context: UIGraphicsPDFRendererContext, currentPage: Int, totalPages: Int) -> CGFloat {
        let footerY = Layout.pageHeight - Layout.margin - 30
        
        // Small company logo in footer
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
        
        // Page number with total count on the right
        let pageText = "Page \(currentPage) of \(totalPages)"
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        
        let pageSize = pageText.size(withAttributes: pageAttributes)
        pageText.draw(at: CGPoint(x: Layout.pageWidth - Layout.margin - pageSize.width, y: footerY + 5), withAttributes: pageAttributes)
        
        return footerY
    }


    private func renderCustomerInfo(context: UIGraphicsPDFRendererContext, inspection: Inspection, at yPosition: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 16) ?? UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
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
        let customerName = "Customer: \(inspection.customer?.name ?? "N/A")"
        let address = "Address: \(inspection.customer?.address ?? "N/A")"
        let inspectionDate = "Date: \(dateFormatter.string(from: inspection.date ?? Date()))"
        
        // Get current inspector name from settings, not from saved inspection
        let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
        let inspector = "Inspector: \(currentInspectorName)"
        
        let infoY = yPosition + 25
        
        customerName.draw(at: CGPoint(x: Layout.margin, y: infoY), withAttributes: attributes)
        address.draw(at: CGPoint(x: Layout.margin + 250, y: infoY), withAttributes: attributes)
        inspectionDate.draw(at: CGPoint(x: Layout.margin, y: infoY + 15), withAttributes: attributes)
        inspector.draw(at: CGPoint(x: Layout.margin + 250, y: infoY + 15), withAttributes: attributes)
        
        return yPosition + 65
    }
    
    // Updated table header for landscape with Arial font - REMOVED "Secondary Location"
    private func renderInspectionTableHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat) -> CGFloat {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 10) ?? UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        // Updated headers - REMOVED "Secondary Location"
        let headers = ["Image", "Primary Location", "Importance", "Issue", "Comments"]
        let columnWidths: [CGFloat] = [70, 140, 80, 220, 280] // Redistributed widths, removed secondary location column
        var xPosition = Layout.margin
        
        // Draw gray background for header
        let headerRect = CGRect(x: Layout.margin,
                               y: yPosition - 5,
                               width: Layout.pageWidth - (Layout.margin * 2),
                               height: 25)
        UIColor(white: 0.9, alpha: 1.0).setFill()
        context.cgContext.fill(headerRect)
        
        // Draw header text
        for (index, header) in headers.enumerated() {
            let columnWidth = columnWidths[index]
            let headerSize = header.size(withAttributes: headerAttributes)
            header.draw(at: CGPoint(x: xPosition + (columnWidth - headerSize.width) / 2, y: yPosition),
                      withAttributes: headerAttributes)
            xPosition += columnWidth
        }
        
        // Draw separator line
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Layout.margin, y: yPosition + 20))
        path.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: yPosition + 20))
        UIColor.black.setStroke()
        path.stroke()
        
        return yPosition + 25
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

    // Updated method to render inspection item with aspect ratio preserved images
    private func renderInspectionItemWithInlinePhoto(context: UIGraphicsPDFRendererContext, item: InspectionItem, at yPosition: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 9) ?? UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 8) ?? UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        
        // Updated column widths - REMOVED secondary location column
        let columnWidths: [CGFloat] = [70, 140, 80, 220, 280]
        var xPosition = Layout.margin
        
        // Photo column with JPEG compression and ASPECT RATIO PRESERVATION
        if item.hasPhoto {
            if let originalImage = item.getPhotoSync() {
                // COMPRESS IMAGE TO HIGH QUALITY JPEG
                let compressedImage: UIImage
                if let jpegData = originalImage.jpegData(compressionQuality: 0.2),
                   let compressed = UIImage(data: jpegData) {
                    compressedImage = compressed
                    print("📸 Compressed image for PDF (quality: 0.2)")
                } else {
                    compressedImage = originalImage
                    print("📸 Using original image (compression failed)")
                }
                
                // Calculate available space for the photo
                let availableWidth = columnWidths[0] - 10 // 5px padding on each side
                let availableHeight = Layout.rowHeight - 10 // 5px padding top and bottom
                
                // Calculate the proper rect maintaining aspect ratio
                let photoRect = calculateAspectFitRect(
                    for: compressedImage,
                    in: CGRect(x: xPosition + 5, y: yPosition + 5, width: availableWidth, height: availableHeight)
                )
                
                // Draw photo border around the actual image size
                let borderRect = CGRect(x: photoRect.minX - 1,
                                  y: photoRect.minY - 1,
                                  width: photoRect.width + 2,
                                  height: photoRect.height + 2)
                UIColor.lightGray.setStroke()
                UIBezierPath(rect: borderRect).stroke()
                
                // Draw compressed photo with preserved aspect ratio
                compressedImage.draw(in: photoRect)
                print("📸 Rendered compressed photo in PDF with preserved aspect ratio")
            } else {
                // Draw placeholder if photo not found
                let placeholderText = "No Photo"
                let placeholderRect = CGRect(x: xPosition + 5,
                                           y: yPosition + 25,
                                           width: columnWidths[0] - 10,
                                           height: 20)
                placeholderText.draw(in: placeholderRect, withAttributes: smallAttributes)
            }
        } else {
            // Draw "No Photo" text
            let placeholderText = "No Photo"
            let placeholderRect = CGRect(x: xPosition + 5,
                                   y: yPosition + 25,
                                   width: columnWidths[0] - 10,
                                   height: 20)
            placeholderText.draw(in: placeholderRect, withAttributes: smallAttributes)
        }
        xPosition += columnWidths[0]
        
        // Primary Location column (expanded width since secondary location removed)
        let primaryLocationString = item.location ?? "N/A"
        let primaryLocationRect = CGRect(x: xPosition + 5, y: yPosition + 10, width: columnWidths[1] - 10, height: Layout.rowHeight - 20)
        drawMultiLineText(primaryLocationString, in: primaryLocationRect, attributes: attributes)
        xPosition += columnWidths[1]
        
        // REMOVED Secondary Location column entirely
        
        // Importance column with triangle icon
        let importanceString = item.importance ?? "Monitor"
        let importanceRect = CGRect(x: xPosition + 5, y: yPosition + 10, width: columnWidths[2] - 10, height: Layout.rowHeight - 20)
        
        if importanceString == "Needs immediate attention" {
            // Draw red triangle icon
            let trianglePoint = CGPoint(x: xPosition + 8, y: yPosition + 12)
            drawTriangleIcon(at: trianglePoint, color: UIColor.red, size: Layout.triangleIconSize)
            
            // Draw text with offset to account for triangle
            let textRect = CGRect(x: xPosition + 8 + Layout.triangleIconSize + 4,
                                y: yPosition + 10,
                                width: columnWidths[2] - 10 - Layout.triangleIconSize - 4,
                                height: Layout.rowHeight - 20)
            drawMultiLineText(importanceString, in: textRect, attributes: attributes)
        } else {
            // Draw text normally for "Monitor"
            drawMultiLineText(importanceString, in: importanceRect, attributes: attributes)
        }
        xPosition += columnWidths[2]
        
        // Issue column with hierarchical bulleted strings
        let issueStrings = getHierarchicalIssueStrings(for: item)
        let issueText = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "\n")
        let issueRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: columnWidths[3] - 10, height: Layout.rowHeight - 10)
        drawMultiLineText(issueText, in: issueRect, attributes: smallAttributes)
        xPosition += columnWidths[3]
        
        // Comments column with improved text wrapping
        let commentsText = item.comments ?? ""
        let commentsRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: columnWidths[4] - 10, height: Layout.rowHeight - 10)
        drawWrappedCommentsText(commentsText, in: commentsRect, attributes: smallAttributes)
        
        // Draw vertical separators between columns
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        
        var separatorX = Layout.margin
        for columnWidth in columnWidths.dropLast() {
            separatorX += columnWidth
            context.cgContext.move(to: CGPoint(x: separatorX, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: separatorX, y: yPosition + Layout.rowHeight))
            context.cgContext.strokePath()
        }
        
        // Draw horizontal separator line
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: Layout.margin, y: yPosition + Layout.rowHeight))
        context.cgContext.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: yPosition + Layout.rowHeight))
        context.cgContext.strokePath()
        
        return yPosition + Layout.rowHeight
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
    func generateCSVReportWithPhotos(inspections: [Inspection], sortCriteria: SortCriteria? = nil) -> ReportPackage? {
        let timestamp = DateFormatter()
        timestamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timeString = timestamp.string(from: Date())
        
        var csvString = "# Systems Inspector Report\n"
        csvString += "# Generated: \(timeString.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: ":"))\n"
        csvString += "# Total Inspections: \(inspections.count)\n"
        csvString += "#\n"
        csvString += "Customer Name,Address,Date,Inspector,Primary Location (Area/Aisle),Secondary Location (Bay/Level),Importance,Issues,Comments,Photo File\n"

        var photoFiles: [String: URL] = [:]
            
        for inspection in inspections {
            let customerName = inspection.customer?.name ?? "N/A"
            let customerAddress = inspection.customer?.address ?? "N/A"
            let inspectionDate = inspection.date ?? Date()
            let inspectorName = inspection.inspectorName ?? "N/A"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateString = dateFormatter.string(from: inspectionDate)

            let items = getSortedInspectionItems(from: inspection, sortCriteria: sortCriteria)

            for item in items {
                let primaryLocation = item.location ?? "N/A"
                let secondaryLocation = item.bayNumber ?? "N/A"
                
                let rawImportance = item.importance ?? "Monitor"
                let importance = rawImportance == "Needs immediate attention" ? "▲ \(rawImportance)" : rawImportance
                
                let issueStrings = getHierarchicalIssueStrings(for: item)
                let issues = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "; ")
                
                let comments = item.comments ?? ""
                
                // FIXED: Handle photo with correct variable name 'item'
                var photoFileName = ""
                if item.hasPhoto {
                    // Try to get photo from CloudKit data first
                    if let photoData = item.photoData {
                        // Create a temporary file for the photo data
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_\(item.id?.uuidString ?? UUID().uuidString).jpg")
                        do {
                            try photoData.write(to: tempURL)
                            let uniquePhotoName = "photo_\(item.id?.uuidString ?? UUID().uuidString).jpg"
                            photoFileName = uniquePhotoName
                            photoFiles[photoFileName] = tempURL
                            print("📸 Added CloudKit photo to CSV export: \(uniquePhotoName)")
                        } catch {
                            print("❌ Failed to create temp file for CloudKit photo: \(error)")
                        }
                    } else if let photoPath = item.photoURL, FileManager.default.fileExists(atPath: photoPath) {
                        // Fallback to local file
                        let photoURL = URL(fileURLWithPath: photoPath)
                        let fileExtension = photoURL.pathExtension
                        let uniquePhotoName = "photo_\(item.id?.uuidString ?? UUID().uuidString).\(fileExtension)"
                        photoFileName = uniquePhotoName
                        photoFiles[photoFileName] = photoURL
                        print("📸 Added local photo to CSV export: \(uniquePhotoName)")
                    }
                }

                csvString += "\"\(customerName)\",\"\(customerAddress)\",\"\(dateString)\",\"\(inspectorName)\",\"\(primaryLocation)\",\"\(secondaryLocation)\",\"\(importance)\",\"\(issues)\",\"\(comments)\",\"\(photoFileName)\"\n"
            }
        }

        guard let csvData = csvString.data(using: .utf8) else {
            return nil
        }
        
        let zipData = createPhotoZip(photoFiles: photoFiles, timestamp: timeString)
        
        let csvFileName = "SystemsInspector_Report_\(timeString).csv"
        let zipFileName = "SystemsInspector_Photos_\(timeString).zip"
        
        return ReportPackage(
            csvData: csvData,
            zipData: zipData,
            csvFileName: csvFileName,
            zipFileName: zipFileName
        )
    }
        
        // MARK: - Photo Zip Creation
        private func createPhotoZip(photoFiles: [String: URL], timestamp: String) -> Data? {
            guard !photoFiles.isEmpty else { return nil }
            
            // Create temporary directory for zip creation
            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("photo_export_\(timestamp)")
            
            do {
                // Create temp directory
                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                
                // Copy all photos to temp directory with new names
                for (newFileName, originalURL) in photoFiles {
                    let destinationURL = tempDirectory.appendingPathComponent(newFileName)
                    // Check if the original file exists before copying
                    guard FileManager.default.fileExists(atPath: originalURL.path) else {
                        print("Skipping missing local photo file: \(originalURL.lastPathComponent)")
                        continue
                    }
                    try FileManager.default.copyItem(at: originalURL, to: destinationURL)
                }
                
                // --- IMPORTANT: ZIPFoundation (or another zipping library) is REQUIRED here ---
                // The following code is a placeholder. For actual ZIP file creation,
                // you would need to integrate a third-party library like 'ZIPFoundation'.
                //
                // To add ZIPFoundation:
                // File -> Add Packages... -> Search for "https://github.com/weichsel/ZIPFoundation"
                // Then, you can use it like this (uncomment and replace the placeholder):
                /*
                import ZIPFoundation // Add this import at the top of the file

                let zipOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_photos_\(timestamp).zip")
                let archive = try Archive(url: zipOutputURL, accessMode: .create)
                
                for (newFileName, _) in photoFiles {
                    let sourceURL = tempDirectory.appendingPathComponent(newFileName)
                    // Add entry to archive. Relative path is important for correct zip structure.
                    // The 'relativeTo' argument should be the directory that contains the files you're zipping.
                    // If files are directly in tempDirectory, then relativeTo: tempDirectory
                    try archive.addEntry(with: sourceURL, relativeTo: tempDirectory) // Corrected from newFileName to sourceURL
                }
                let zippedData = try Data(contentsOf: zipOutputURL)
                // Remove the temporary directory after zipping
                try? FileManager.default.removeItem(at: tempDirectory)
                return zippedData
                */
                
                // --- Placeholder for demonstration without ZIPFoundation ---
                let zipOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_photos_\(timestamp).zip")
                let dummyZipData = "This is a dummy zip file. Please integrate a proper zipping library like ZIPFoundation for actual zipping.".data(using: .utf8)
                try dummyZipData?.write(to: zipOutputURL)
                
                let zippedData = try Data(contentsOf: zipOutputURL)
                print("ReportGenerator: Dummy zip file created. Integrate ZIPFoundation for real zipping.")
                // --- End Placeholder ---
                
                // Cleanup temp directory (only if not handled by ZIPFoundation or similar within its block)
                try? FileManager.default.removeItem(at: tempDirectory)
                
                return zippedData
                
            } catch {
                print("Error creating photo zip: \(error)")
                // Cleanup on error
                try? FileManager.default.removeItem(at: tempDirectory)
                return nil
            }
        }
        
        // MARK: - Legacy CSV method (keep for backward compatibility)
        func generateCSVReport(inspections: [Inspection], sortCriteria: SortCriteria? = nil) -> Data? {
            // Keep the original method for backward compatibility
            let reportPackage = generateCSVReportWithPhotos(inspections: inspections, sortCriteria: sortCriteria)
            return reportPackage?.csvData
        }
    
    // UPDATED: Better handling of entry order and default sorting
    private func getSortedInspectionItems(from inspection: Inspection, sortCriteria: SortCriteria? = nil) -> [InspectionItem] {
        let items: [InspectionItem] = (inspection.items)?.allObjects as? [InspectionItem] ?? []
        
        // Default to entry order if no criteria specified
        let criteria = sortCriteria ?? .entryOrder
        
        switch criteria {
        case .importance:
            return items.sorted { item1, item2 in
                let importance1 = item1.importance ?? "Monitor"
                let importance2 = item2.importance ?? "Monitor"
                
                if importance1 == "Needs immediate attention" && importance2 == "Monitor" {
                    return true
                } else if importance1 == "Monitor" && importance2 == "Needs immediate attention" {
                    return false
                }
                
                return (item1.location ?? "") < (item2.location ?? "")
            }
            
        case .primaryLocation:
            return items.sorted { item1, item2 in
                let location1 = item1.location ?? ""
                let location2 = item2.location ?? ""
                
                // Use natural sorting with numeric option
                let result = location1.compare(location2, options: [.numeric, .caseInsensitive])
                
                if result == .orderedSame {
                    let bay1 = item1.bayNumber ?? ""
                    let bay2 = item2.bayNumber ?? ""
                    return bay1.compare(bay2, options: [.numeric, .caseInsensitive]) == .orderedAscending
                }
                
                return result == .orderedAscending
            }
            
        case .issue:
            return items.sorted { item1, item2 in
                let issue1 = getPrimaryIssueType(for: item1)
                let issue2 = getPrimaryIssueType(for: item2)
                
                if issue1 == issue2 {
                    return (item1.location ?? "") < (item2.location ?? "")
                }
                
                return issue1 < issue2
            }
            
        case .entryOrder:
            // BEST: Use sequence numbers for reliable entry order
            return items.sorted { item1, item2 in
                return item1.sequenceNumber < item2.sequenceNumber
            }
            
        case .date, .customer, .inspectionStatus:
            // For inspection-level sorting, return items in entry order
            return items.sorted { item1, item2 in
                return item1.sequenceNumber < item2.sequenceNumber
            }
        }
    }

    private func getPrimaryIssueType(for item: InspectionItem) -> String {
        if item.upright { return "Upright" }
        if item.beam { return "Beam" }
        if item.wireDeck { return "Wire Deck" }
        if item.basePlate { return "Base Plate" }
        if item.anchors { return "Anchors" }
        if item.bracingDamage { return "Bracing" }
        if item.postProtector { return "Post Protector" }
        if item.aisleGuarding { return "Aisle Guarding" }
        return "No Issues"
    }
    
    private func getHierarchicalIssueStrings(for item: InspectionItem) -> [String] {
        var issueStrings: [String] = []
        
        func addIssueString(_ parentName: String, _ childName: String? = nil, _ grandchildName: String? = nil) {
            var issueString = "• \(parentName)"
            if let child = childName {
                issueString += " > \(child)"
                if let grandchild = grandchildName {
                    issueString += " > \(grandchild)"
                }
            }
            issueStrings.append(issueString)
        }
        
        if item.upright {
            if item.uprightFrontDamage { addIssueString("Upright", "Front", "Damage") }
            if item.uprightFrontTwisted { addIssueString("Upright", "Front", "Twisted") }
            if item.uprightRearDamage { addIssueString("Upright", "Rear", "Damage") }
            if item.uprightRearTwisted { addIssueString("Upright", "Rear", "Twisted") }
            if item.uprightAlignmentOutOfAlignment { addIssueString("Upright", "Alignment", "Out of alignment") }
            if item.uprightAlignmentOutOfVerticalPlumb { addIssueString("Upright", "Alignment", "Out of vertical plumb") }
            
            if !item.uprightFrontDamage && !item.uprightFrontTwisted &&
               !item.uprightRearDamage && !item.uprightRearTwisted &&
               !item.uprightAlignmentOutOfAlignment && !item.uprightAlignmentOutOfVerticalPlumb {
                addIssueString("Upright")
            }
        }
        
        if item.beam {
            if item.beamFrontDamage { addIssueString("Beam", "Front damage") }
            if item.beamRearDamage { addIssueString("Beam", "Rear damage") }
            if item.beamFrontBowed { addIssueString("Beam", "Front bowed") }
            if item.beamRearBowed { addIssueString("Beam", "Rear bowed") }
            if !item.beamFrontDamage && !item.beamRearDamage && !item.beamFrontBowed && !item.beamRearBowed {
                addIssueString("Beam")
            }
        }
        
        if item.wireDeck {
            if item.wireDeckMissing { addIssueString("Wire Deck", "Missing") }
            if item.wireDeckDamaged { addIssueString("Wire Deck", "Damaged") }
            if item.wireDeckOutOfPosition { addIssueString("Wire Deck", "Out of position") }
            if !item.wireDeckMissing && !item.wireDeckDamaged && !item.wireDeckOutOfPosition {
                addIssueString("Wire Deck")
            }
        }
        
        if item.basePlate {
            if item.basePlateFloorDamaged { addIssueString("Base Plate", "Floor damaged") }
            if item.basePlateTwisted { addIssueString("Base Plate", "Twisted") }
            if item.basePlateDamaged { addIssueString("Base Plate", "Damaged") }
            if !item.basePlateFloorDamaged && !item.basePlateTwisted && !item.basePlateDamaged {
                addIssueString("Base Plate")
            }
        }
        
        if item.anchors {
            if item.anchorsMissing { addIssueString("Anchors", "Missing anchors or bolts") }
            if item.anchorsDamaged { addIssueString("Anchors", "Damaged or bent") }
            if item.anchorsTorqued { addIssueString("Anchors", "Torqued to 35lbs") }
            if !item.anchorsMissing && !item.anchorsDamaged && !item.anchorsTorqued {
                addIssueString("Anchors")
            }
        }
        
        if item.bracingDamage {
            if item.bracingHorizontal { addIssueString("Bracing Damage", "Horizontal") }
            if item.bracingDiagonal { addIssueString("Bracing Damage", "Diagonal") }
            if !item.bracingHorizontal && !item.bracingDiagonal {
                addIssueString("Bracing Damage")
            }
        }
        
        if item.postProtector {
            if item.postProtectorMissing { addIssueString("Post Protector", "Missing") }
            if item.postProtectorDamaged { addIssueString("Post Protector", "Damaged") }
            if item.postProtectorRepairRequired { addIssueString("Post Protector", "Repair required") }
            if !item.postProtectorMissing && !item.postProtectorDamaged && !item.postProtectorRepairRequired {
                addIssueString("Post Protector")
            }
        }
        
        if item.aisleGuarding {
            if item.aisleGuardingMissing { addIssueString("Aisle Guarding", "Missing") }
            if item.aisleGuardingDamaged { addIssueString("Aisle Guarding", "Damaged") }
            if item.aisleGuardingRepairRequired { addIssueString("Aisle Guarding", "Repair required") }
            if !item.aisleGuardingMissing && !item.aisleGuardingDamaged && !item.aisleGuardingRepairRequired {
                addIssueString("Aisle Guarding")
            }
        }
        
        return issueStrings
    }
    
    // MARK: - Helper Methods (Update existing method)
    func getFilteredInspections(sortBy: SortCriteria, filters: [Filter]) -> [Inspection] {
        guard let currentUserID = CoreDataManager.shared.currentUserID else {
            print("ReportGenerator: No current user ID. Not fetching filtered inspections.")
            return []
        }

        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Always filter by current user ID
        predicates.append(NSPredicate(format: "userId == %@", currentUserID as CVarArg))
        
        // Apply additional filters
        if !filters.isEmpty {
            for filter in filters {
                switch filter.key {
                case "customer":
                    predicates.append(NSPredicate(format: "customer.name CONTAINS[cd] %@", filter.value))
                case "date":
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: filter.value) {
                        predicates.append(NSPredicate(format: "date >= %@ AND date < %@",
                                                    date as NSDate,
                                                    date.addingTimeInterval(86400) as NSDate))
                    }
                case "inspector":
                    predicates.append(NSPredicate(format: "inspectorName CONTAINS[cd] %@", filter.value))
                default:
                    break
                }
            }
        }
        
        // Combine all predicates
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Apply sorting
        switch sortBy {
        case .date:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .customer:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "customer.name", ascending: true)]
        case .inspectionStatus:
            // Assuming inspectionStatus is handled by additional filtering or a specific Core Data attribute
            // For now, default to sorting by date if not explicitly defined
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .importance, .primaryLocation, .issue, .entryOrder:
            // For item-level sorting, sort inspections by date first
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        }
        
        do {
            let inspections = try context.fetch(fetchRequest)
            return inspections
        } catch {
            print("Error fetching filtered inspections: \(error)")
            return []
        }
    }
    
    private func getIssueDescription(for item: InspectionItem) -> String {
        var issues: [String] = []
        
        if item.upright { issues.append("Upright") }
        if item.beam { issues.append("Beam") }
        if item.wireDeck { issues.append("Wire Deck") }
        if item.basePlate { issues.append("Base Plate") }
        if item.anchors { issues.append("Anchors") }
        if item.bracingDamage { issues.append("Bracing") }
        if item.postProtector { issues.append("Post Protector") }
        if item.aisleGuarding { issues.append("Aisle Guarding") }
        
        return issues.isEmpty ? "None" : issues.joined(separator: ", ")
    }
    
}
// MARK: - Enhanced Photo Collection Helper
extension ReportGenerator {
    
    /// Collect all unique photos from inspections
    private func collectPhotosFromInspections(_ inspections: [Inspection]) -> [URL] {
        var photoURLs: Set<String> = []
        var photos: [URL] = []
        
        for inspection in inspections {
            // The 'items' property of 'Inspection' is a relationship, and Core Data handles
            // fetching related objects. Assuming these 'items' already belong to the user.
            let items = getSortedInspectionItems(from: inspection, sortCriteria: nil)
            
            for item in items {
                if let photoPath = item.photoURL {
                    // Check if the photo is locally available
                    if FileManager.default.fileExists(atPath: photoPath) {
                        // Only add if not already added to avoid duplicates if multiple items share a photo
                        if !photoURLs.contains(photoPath) {
                            photoURLs.insert(photoPath)
                            photos.append(URL(fileURLWithPath: photoPath))
                        }
                    } else {
                        print("ReportGenerator: Photo file not found locally for path: \(photoPath). Will not be included in zip.")
                    }
                }
            }
        }
        
        return photos
    }
    
    /// Generate photo summary for CSV header
    private func generatePhotoSummary(for inspections: [Inspection]) -> String {
        let photos = collectPhotosFromInspections(inspections)
        return "# Total Photos: \(photos.count)\n"
    }
}
