//
//  ReportGenerator.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import PDFKit
import CoreData
import Compression

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
            if let customer = inspection.customer {
                currentY = renderCustomerInfo(context: context, inspection: inspection, at: currentY)
            } else {
                currentY += 50
                print("Warning: Inspection has no associated customer for PDF report.")
            }
            currentY = renderInspectionTableHeader(context: context, at: currentY)
            
            // Get sorted inspection items
            let items = getSortedInspectionItems(from: inspection, sortCriteria: sortCriteria)
            
            // Render each inspection item with inline photos
            for (index, item) in items.enumerated() {
                // Calculate if this item would fit on current page
                let spaceNeeded = Layout.rowHeight
                let spaceAvailable = Layout.pageHeight - Layout.margin - 60 - currentY // 60 for footer space
                
                // If item won't fit, start new page
                if spaceAvailable < spaceNeeded {
                    // Render footer before new page
                    renderFooter(context: context, currentPage: currentPage, totalPages: totalPages)
                    
                    // Start new page
                    context.beginPage()
                    currentPage += 1
                    currentY = Layout.margin
                    currentY = renderInspectionTableHeader(context: context, at: currentY)
                }
                
                currentY = renderInspectionItemWithInlinePhoto(context: context, item: item, at: currentY)
            }
            
            // Render footer on the last page
            renderFooter(context: context, currentPage: currentPage, totalPages: totalPages)
        }
    }
    
    // MARK: - Rendering Components (Updated with no timestamps and better spacing)
    private func renderHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat) -> CGFloat {
        // Company logo - positioned on the left (50% larger)
        var logoHeight: CGFloat = 0
        if let logoImage = UIImage(named: "company_logo") {
            // Calculate logo dimensions maintaining aspect ratio (50% larger)
            let maxLogoWidth: CGFloat = 210  // Increased from 120 (50% larger)
            let maxLogoHeight: CGFloat = 105   // Increased from 60 (50% larger)
            
            let logoAspectRatio = logoImage.size.width / logoImage.size.height
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
        }
        
        // Title - centered
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 24) ?? UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let title = "Inspection Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (Layout.pageWidth - titleSize.width) / 2
        let titleY = yPosition + max(0, (logoHeight - titleSize.height) / 2) // Center vertically with logo
        
        title.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttributes)
        
        // UPDATED: Company info positioned much further right and removed generated timestamp
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
        
        // UPDATED: Move company info much further right (increased margin significantly)
        let rightSideX = Layout.pageWidth - Layout.margin - 150 // Reduced from 300 to 200 (moving further right)
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
        
        // REMOVED: Generated timestamp is no longer displayed
        
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
        let footerHeight: CGFloat = 50 // Space reserved for footer
        let availableHeight = Layout.pageHeight - (Layout.margin * 2) - headerHeight - footerHeight
        let rowsPerPage = Int(availableHeight / Layout.rowHeight)
        
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

    // UPDATED: Footer with no generation timestamp
    private func renderFooter(context: UIGraphicsPDFRendererContext, currentPage: Int, totalPages: Int) -> CGFloat {
        let footerY = Layout.pageHeight - Layout.margin - 30
        
        // Small company logo in footer
        if let logoImage = UIImage(named: "company_logo") {
            let smallLogoSize: CGFloat = 20
            let logoAspectRatio = logoImage.size.width / logoImage.size.height
            let smallLogoWidth = smallLogoSize * logoAspectRatio
            
            let logoRect = CGRect(
                x: Layout.margin,
                y: footerY,
                width: smallLogoWidth,
                height: smallLogoSize
            )
            
            logoImage.draw(in: logoRect)
        }
        
        // Page number with total count on the right
        let pageText = "Page \(currentPage) of \(totalPages)"
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        
        let pageSize = pageText.size(withAttributes: pageAttributes)
        pageText.draw(at: CGPoint(x: Layout.pageWidth - Layout.margin - pageSize.width, y: footerY + 5), withAttributes: pageAttributes)
        
        // REMOVED: Generation timestamp no longer displayed in footer
        
        return footerY
    }


    // FIXED: Update customer info section to use current inspector name from settings
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
        
        // FIXED: Get current inspector name from settings, not from saved inspection
        let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
        let inspector = "Inspector: \(currentInspectorName)"
        
        let infoY = yPosition + 25
        
        customerName.draw(at: CGPoint(x: Layout.margin, y: infoY), withAttributes: attributes)
        address.draw(at: CGPoint(x: Layout.margin + 250, y: infoY), withAttributes: attributes)
        inspectionDate.draw(at: CGPoint(x: Layout.margin, y: infoY + 15), withAttributes: attributes)
        inspector.draw(at: CGPoint(x: Layout.margin + 250, y: infoY + 15), withAttributes: attributes)
        
        return yPosition + 65
    }
    
    // Updated table header for landscape with Arial font
    private func renderInspectionTableHeader(context: UIGraphicsPDFRendererContext, at yPosition: CGFloat) -> CGFloat {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Arial-BoldMT", size: 10) ?? UIFont.boldSystemFont(ofSize: 10), // CHANGED to Arial Bold
            .foregroundColor: UIColor.black
        ]
        
        // Updated headers with Photo column
        let headers = ["Image", "Primary Location", "Secondary Location", "Importance", "Issue", "Comments"]
        let columnWidths: [CGFloat] = [70, 120, 120, 80, 200, 200] // Specific widths for each column
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

    // Updated method to render inspection item with Arial fonts
    private func renderInspectionItemWithInlinePhoto(context: UIGraphicsPDFRendererContext, item: InspectionItem, at yPosition: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 9) ?? UIFont.systemFont(ofSize: 9), // CHANGED to Arial
            .foregroundColor: UIColor.black
        ]
        
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "ArialMT", size: 8) ?? UIFont.systemFont(ofSize: 8), // CHANGED to Arial
            .foregroundColor: UIColor.black
        ]
        
        let columnWidths: [CGFloat] = [70, 120, 120, 80, 200, 200]
        var xPosition = Layout.margin
        
        // Photo column
        if let photoPath = item.photoURL {
            let photoURL = URL(fileURLWithPath: photoPath)
            if let image = UIImage(contentsOfFile: photoURL.path) {
                let photoRect = CGRect(x: xPosition + 5,
                                     y: yPosition + 5,
                                     width: Layout.inlinePhotoSize,
                                     height: Layout.inlinePhotoSize)
                
                // Draw photo border
                let borderRect = CGRect(x: photoRect.minX - 1,
                                      y: photoRect.minY - 1,
                                      width: photoRect.width + 2,
                                      height: photoRect.height + 2)
                UIColor.lightGray.setStroke()
                UIBezierPath(rect: borderRect).stroke()
                
                // Draw photo
                image.draw(in: photoRect)
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
        
        // Primary Location column
        let primaryLocationString = item.location ?? "N/A"
        let primaryLocationRect = CGRect(x: xPosition + 5, y: yPosition + 10, width: columnWidths[1] - 10, height: Layout.rowHeight - 20)
        drawMultiLineText(primaryLocationString, in: primaryLocationRect, attributes: attributes)
        xPosition += columnWidths[1]
        
        // Secondary Location column
        let secondaryLocationString = item.bayNumber ?? "N/A"
        let secondaryLocationRect = CGRect(x: xPosition + 5, y: yPosition + 10, width: columnWidths[2] - 10, height: Layout.rowHeight - 20)
        drawMultiLineText(secondaryLocationString, in: secondaryLocationRect, attributes: attributes)
        xPosition += columnWidths[2]
        
        // Importance column with triangle icon
        let importanceString = item.importance ?? "Monitor"
        let importanceRect = CGRect(x: xPosition + 5, y: yPosition + 10, width: columnWidths[3] - 10, height: Layout.rowHeight - 20)
        
        if importanceString == "Needs immediate attention" {
            // Draw red triangle icon
            let trianglePoint = CGPoint(x: xPosition + 8, y: yPosition + 12)
            drawTriangleIcon(at: trianglePoint, color: UIColor.red, size: Layout.triangleIconSize)
            
            // Draw text with offset to account for triangle
            let textRect = CGRect(x: xPosition + 8 + Layout.triangleIconSize + 4,
                                y: yPosition + 10,
                                width: columnWidths[3] - 10 - Layout.triangleIconSize - 4,
                                height: Layout.rowHeight - 20)
            drawMultiLineText(importanceString, in: textRect, attributes: attributes)
        } else {
            // Draw text normally for "Monitor"
            drawMultiLineText(importanceString, in: importanceRect, attributes: attributes)
        }
        xPosition += columnWidths[3]
        
        // Issue column with hierarchical bulleted strings - EACH ON ITS OWN LINE
        let issueStrings = getHierarchicalIssueStrings(for: item)
        let issueText = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "\n")
        let issueRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: columnWidths[4] - 10, height: Layout.rowHeight - 10)
        drawMultiLineText(issueText, in: issueRect, attributes: smallAttributes)
        xPosition += columnWidths[4]
        
        // Comments column
        let commentsText = item.comments ?? ""
        let commentsRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: columnWidths[5] - 10, height: Layout.rowHeight - 10)
        drawMultiLineText(commentsText, in: commentsRect, attributes: smallAttributes)
        
        // Draw vertical separators between columns
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        
        var separatorX = Layout.margin
        for columnWidth in columnWidths.dropLast() { // Don't draw separator after last column
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
    
    // Updated method to handle multi-line text with Arial font
    private func drawMultiLineText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let attributedString = NSMutableAttributedString(string: text, attributes: attributes)
        
        // Set paragraph style for better line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        
        // Use NSAttributedString's built-in drawing with proper bounds
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        attributedString.draw(with: rect, options: options, context: nil)
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
            
            // Create CSV with photo column
            var csvString = "# Systems Inspector Report\n"
            csvString += "# Generated: \(timeString.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: ":"))\n"
            csvString += "# Total Inspections: \(inspections.count)\n"
            csvString += "#\n"
            csvString += "Customer Name,Address,Date,Inspector,Primary Location (Area/Aisle),Secondary Location (Bay/Level),Importance,Issues,Comments,Photo File\n"

            // Collect photos and generate CSV rows
            var photoFiles: [String: URL] = [:]
            var photoCounter = 1
            
            for inspection in inspections {
                let customerName = inspection.customer?.name ?? "N/A"
                let customerAddress = inspection.customer?.address ?? "N/A"
                let inspectionDate = inspection.date ?? Date()
                let inspectorName = inspection.inspectorName ?? "N/A"
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let dateString = dateFormatter.string(from: inspectionDate)

                // Get sorted inspection items
                let items = getSortedInspectionItems(from: inspection, sortCriteria: sortCriteria)

                for item in items {
                    let primaryLocation = item.location ?? "N/A"
                    let secondaryLocation = item.bayNumber ?? "N/A"
                    
                    // Add triangle indicator for CSV
                    let rawImportance = item.importance ?? "Monitor"
                    let importance = rawImportance == "Needs immediate attention" ? "▲ \(rawImportance)" : rawImportance
                    
                    let issueStrings = getHierarchicalIssueStrings(for: item)
                    let issues = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "; ") // Use semicolon for CSV
                    
                    let comments = item.comments ?? ""
                    
                    // Handle photo
                    var photoFileName = ""
                    if let photoPath = item.photoURL {
                        let photoURL = URL(fileURLWithPath: photoPath)
                        if FileManager.default.fileExists(atPath: photoPath) {
                            // Create a clean filename
                            let fileExtension = photoURL.pathExtension
                            photoFileName = "photo_\(String(format: "%03d", photoCounter)).\(fileExtension)"
                            photoFiles[photoFileName] = photoURL
                            photoCounter += 1
                        }
                    }

                    csvString += "\"\(customerName)\",\"\(customerAddress)\",\"\(dateString)\",\"\(inspectorName)\",\"\(primaryLocation)\",\"\(secondaryLocation)\",\"\(importance)\",\"\(issues)\",\"\(comments)\",\"\(photoFileName)\"\n"
                }
            }

            guard let csvData = csvString.data(using: .utf8) else {
                return nil
            }
            
            // Create zip file with photos
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
            let zipURL = tempDirectory.appendingPathComponent("photos.zip")
            
            do {
                // Create temp directory
                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                
                // Copy all photos to temp directory with new names
                for (newFileName, originalURL) in photoFiles {
                    let destinationURL = tempDirectory.appendingPathComponent(newFileName)
                    try FileManager.default.copyItem(at: originalURL, to: destinationURL)
                }
                
                // Create zip file
                let zipData = try createZipFile(from: tempDirectory, photoFiles: Array(photoFiles.keys))
                
                // Cleanup temp directory
                try? FileManager.default.removeItem(at: tempDirectory)
                
                return zipData
                
            } catch {
                print("Error creating photo zip: \(error)")
                // Cleanup on error
                try? FileManager.default.removeItem(at: tempDirectory)
                return nil
            }
        }
        
        // MARK: - Zip File Creation using Foundation
        private func createZipFile(from directory: URL, photoFiles: [String]) -> Data? {
            // Use NSFileCoordinator for thread-safe file operations
            var coordinatorError: NSError?
            var zipData: Data?
            
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { (url) in
                do {
                    // Create archive using Foundation's built-in compression
                    zipData = try Data(contentsOf: url)
                } catch {
                    print("Error reading zip data: \(error)")
                }
            }
            
            if let error = coordinatorError {
                print("Coordinator error: \(error)")
                return nil
            }
            
            return zipData
        }
        
        // MARK: - Alternative Zip Creation (Manual Implementation)
        private func createZipFileManual(photoFiles: [String: URL]) -> Data? {
            // This is a more manual approach if the Foundation method doesn't work
            let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("photos_\(UUID().uuidString).zip")
            
            do {
                // Create empty zip file
                let zipData = NSMutableData()
                
                // Add each photo to zip (this is a simplified approach)
                // For production, you might want to use a proper zip library like ZIPFoundation
                
                // Write zip file
                try zipData.write(to: tempZipURL)
                let data = try Data(contentsOf: tempZipURL)
                
                // Cleanup
                try? FileManager.default.removeItem(at: tempZipURL)
                
                return data
                
            } catch {
                print("Error creating manual zip: \(error)")
                try? FileManager.default.removeItem(at: tempZipURL)
                return nil
            }
        }
    
    // MARK: - Legacy CSV method (keep for backward compatibility)
        func generateCSVReport(inspections: [Inspection], sortCriteria: SortCriteria? = nil) -> Data? {
            // Keep the original method for backward compatibility
            let reportPackage = generateCSVReportWithPhotos(inspections: inspections, sortCriteria: sortCriteria)
            return reportPackage?.csvData
        }
    
    // Add this method to get sorted inspection items
    private func getSortedInspectionItems(from inspection: Inspection, sortCriteria: SortCriteria? = nil) -> [InspectionItem] {
        let items: [InspectionItem] = (inspection.items)?.allObjects as? [InspectionItem] ?? []
        
        guard let criteria = sortCriteria else {
            // If no specific sorting criteria, return items as they are in the inspection
            return items
        }
        
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
                
                if location1 == location2 {
                    return (item1.bayNumber ?? "") < (item2.bayNumber ?? "")
                }
                
                return location1 < location2
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
            return items.sorted { item1, item2 in
                return item1.id?.uuidString ?? "" < item2.id?.uuidString ?? ""
            }
            
        default:
            return items
        }
    }

    private func getPrimaryIssueType(for item: InspectionItem) -> String {
        if item.upright { return "Upright" }
        if item.beam { return "Beam" }
        if item.wireDeck { return "Wire Deck" }
        if item.basePlate { return "Base Plate" }
        if item.anchors { return "Anchors" }
        if item.bracingDamage { return "Bracing Damage" }
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
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        
        // Apply filters
        if !filters.isEmpty {
            var predicates: [NSPredicate] = []
            
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
            
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
        }
        
        // Apply sorting
        switch sortBy {
        case .date:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .customer:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "customer.name", ascending: true)]
        case .inspectionStatus:
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
            let items = getSortedInspectionItems(from: inspection, sortCriteria: nil)
            
            for item in items {
                if let photoPath = item.photoURL,
                   !photoURLs.contains(photoPath),
                   FileManager.default.fileExists(atPath: photoPath) {
                    photoURLs.insert(photoPath)
                    photos.append(URL(fileURLWithPath: photoPath))
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
