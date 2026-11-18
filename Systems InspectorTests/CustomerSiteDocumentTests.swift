//
//  CustomerSiteDocumentTests.swift
//  Systems InspectorTests
//

import CoreData
import UIKit
import XCTest
@testable import Systems_Inspector

final class CustomerSiteDocumentTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            XCTFail("Missing Core Data model")
            return
        }
        container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)
        context = container.viewContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeCustomer() -> Customer {
        let customer = Customer(context: context)
        customer.id = UUID()
        customer.name = "Acme"
        return customer
    }

    func testReplaceCapsAtFive() {
        let customer = makeCustomer()
        let files = (0..<6).map { i in
            SiteDocumentFile(id: nil, filename: "f\(i).pdf", contentType: "public.pdf", data: Data([UInt8(i)]))
        }
        customer.replaceDocuments(files, userId: UUID())
        XCTAssertEqual(customer.documentFiles().count, 5)
        XCTAssertEqual(customer.documentFiles().map(\.filename), ["f0.pdf", "f1.pdf", "f2.pdf", "f3.pdf", "f4.pdf"])
    }

    func testKeepByIdDoesNotRewriteData() {
        let userId = UUID()
        let customer = makeCustomer()
        let original = Data([1, 2, 3])
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "a.jpg", contentType: "public.jpeg", data: original)
        ], userId: userId)
        let id = customer.documentFiles()[0].id
        XCTAssertNotNil(id)
        customer.replaceDocuments([
            SiteDocumentFile(id: id, filename: "a.jpg", contentType: "public.jpeg", data: Data([9, 9, 9]))
        ], userId: userId)
        XCTAssertEqual(customer.documentFiles()[0].data, original)
    }

    func testAcceptance() {
        let exact = Data(count: Customer.maxSiteDocumentBytes)
        XCTAssertEqual(Customer.acceptance(data: exact, contentType: "public.pdf"), .allowed)
        XCTAssertEqual(Customer.acceptance(data: exact, contentType: "public.jpeg"), .allowed)
        XCTAssertEqual(Customer.acceptance(data: exact, contentType: "public.png"), .allowed)
        XCTAssertEqual(
            Customer.acceptance(data: Data(count: Customer.maxSiteDocumentBytes + 1), contentType: "public.pdf"),
            .tooLarge
        )
        XCTAssertEqual(Customer.acceptance(data: Data([1]), contentType: "public.data"), .wrongType)
        XCTAssertNil(Customer.SiteDocumentAcceptance.allowed.message)
        XCTAssertEqual(Customer.SiteDocumentAcceptance.tooLarge.message, "Each file must be 10 MB or smaller.")
        XCTAssertEqual(Customer.SiteDocumentAcceptance.wrongType.message, "Use a photo or PDF.")
        XCTAssertEqual(
            Customer.acceptance(data: Data(count: Customer.maxSiteDocumentBytes + 1), contentType: "public.data"),
            .tooLarge
        )
    }

    func testReplaceStoresExactlyTenMegabytes() {
        let customer = makeCustomer()
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "full.pdf", contentType: "public.pdf", data: Data(count: Customer.maxSiteDocumentBytes))
        ], userId: UUID())
        XCTAssertEqual(customer.documentFiles().map(\.filename), ["full.pdf"])
        XCTAssertEqual(customer.documentFiles()[0].data.count, Customer.maxSiteDocumentBytes)
    }

    func testReplaceDropsAnOversizedFile() {
        let customer = makeCustomer()
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "big.pdf", contentType: "public.pdf", data: Data(count: Customer.maxSiteDocumentBytes + 1))
        ], userId: UUID())
        XCTAssertEqual(customer.documentFiles(), [])
    }

    func testReplaceDropsAWrongType() {
        let customer = makeCustomer()
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "notes.txt", contentType: "public.data", data: Data([1]))
        ], userId: UUID())
        XCTAssertEqual(customer.documentFiles(), [])
    }

    func testRefusedFileDoesNotTakeASlot() {
        let customer = makeCustomer()
        let refused = SiteDocumentFile(
            id: nil,
            filename: "big.pdf",
            contentType: "public.pdf",
            data: Data(count: Customer.maxSiteDocumentBytes + 1)
        )
        let allowed = (0..<5).map { i in
            SiteDocumentFile(id: nil, filename: "f\(i).pdf", contentType: "public.pdf", data: Data([UInt8(i)]))
        }
        customer.replaceDocuments([refused] + allowed, userId: UUID())
        XCTAssertEqual(customer.documentFiles().map(\.filename), ["f0.pdf", "f1.pdf", "f2.pdf", "f3.pdf", "f4.pdf"])
    }

    func testSiteDocumentEntry() async throws {
        let image = solidImage(size: CGSize(width: 80, height: 40))
        let photo = await Customer.siteDocumentEntry(
            image: image,
            filename: "site-photo.jpg",
            existingCount: 0
        )
        guard case .document(let photoFile) = photo else {
            return XCTFail("Expected a photo document, got \(photo)")
        }
        XCTAssertNil(photoFile.id)
        XCTAssertEqual(photoFile.contentType, "public.jpeg")
        XCTAssertEqual(photoFile.filename, "site-photo.jpg")
        XCTAssertNotNil(UIImage(data: photoFile.data))

        let fullPhoto = await Customer.siteDocumentEntry(
            image: image,
            filename: "site-photo.jpg",
            existingCount: Customer.maxSiteDocumentCount
        )
        XCTAssertEqual(fullPhoto, .full)

        let pdf = Data([0x25, 0x50, 0x44, 0x46])
        let kept = await Customer.siteDocumentEntry(
            data: pdf,
            contentType: "public.pdf",
            filename: "plan.pdf",
            existingCount: 0
        )
        guard case .document(let pdfFile) = kept else {
            return XCTFail("Expected a PDF document, got \(kept)")
        }
        XCTAssertNil(pdfFile.id)
        XCTAssertEqual(pdfFile.data, pdf)
        XCTAssertEqual(pdfFile.filename, "plan.pdf")
        XCTAssertEqual(pdfFile.contentType, "public.pdf")

        let png = try XCTUnwrap(image.pngData())
        let converted = await Customer.siteDocumentEntry(
            data: png,
            contentType: "public.png",
            filename: "nameplate.png",
            existingCount: 0
        )
        guard case .document(let pngFile) = converted else {
            return XCTFail("Expected a JPEG document, got \(converted)")
        }
        XCTAssertEqual(pngFile.contentType, "public.jpeg")
        XCTAssertEqual(pngFile.filename, "nameplate.jpg")
        XCTAssertNotNil(UIImage(data: pngFile.data))

        let oversized = Data(count: Customer.maxSiteDocumentBytes + 1)
        let tooLarge = await Customer.siteDocumentEntry(
            data: oversized,
            contentType: "public.pdf",
            filename: "big.pdf",
            existingCount: 0
        )
        guard case .refused(let acceptance) = tooLarge else {
            return XCTFail("Expected too large, got \(tooLarge)")
        }
        XCTAssertEqual(acceptance, .tooLarge)
        XCTAssertEqual(acceptance.message, "Each file must be 10 MB or smaller.")

        let garbage = Data([0x00, 0x01])
        let unreadable = await Customer.siteDocumentEntry(
            data: garbage,
            contentType: "public.jpeg",
            filename: "x.jpg",
            existingCount: 0
        )
        XCTAssertEqual(unreadable, .unreadable)

        let fullGarbage = await Customer.siteDocumentEntry(
            data: garbage,
            contentType: "public.jpeg",
            filename: "x.jpg",
            existingCount: Customer.maxSiteDocumentCount
        )
        XCTAssertEqual(fullGarbage, .full)

        let fullOversized = await Customer.siteDocumentEntry(
            data: oversized,
            contentType: "public.pdf",
            filename: "big.pdf",
            existingCount: Customer.maxSiteDocumentCount
        )
        XCTAssertEqual(fullOversized, .full)
    }

    func testMissingIdDeletesDocument() {
        let customer = makeCustomer()
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1])),
            SiteDocumentFile(id: nil, filename: "b.pdf", contentType: "public.pdf", data: Data([2]))
        ], userId: UUID())
        let keep = customer.documentFiles()[0]
        customer.replaceDocuments([keep], userId: UUID())
        XCTAssertEqual(customer.documentFiles().map(\.filename), [keep.filename])
    }

    private func solidImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
