//
//  Customer+SiteDocuments.swift
//  Systems Inspector
//

import CoreData
import Foundation

extension Customer {
    static let maxSiteDocumentCount = 5
    static let allowedContentTypes: Set<String> = ["public.jpeg", "public.png", "public.pdf"]
    static let maxSiteDocumentBytes = 10 * 1024 * 1024

    func documentFiles() -> [SiteDocumentFile] {
        let docs = (siteDocuments as? Set<SiteDocument>) ?? []
        return docs.sorted { $0.sortIndex < $1.sortIndex }.compactMap { doc in
            guard let data = doc.data else { return nil }
            return SiteDocumentFile(
                id: doc.id,
                filename: doc.filename ?? "file",
                contentType: doc.contentType ?? "public.data",
                data: data
            )
        }
    }

    func replaceDocuments(_ files: [SiteDocumentFile], userId: UUID) {
        let limited = Array(files.prefix(Self.maxSiteDocumentCount))
        let keepIds = Set(limited.compactMap(\.id))
        let existing = (siteDocuments as? Set<SiteDocument>) ?? []
        let context = managedObjectContext
        for doc in existing where doc.id == nil || !keepIds.contains(doc.id!) {
            context?.delete(doc)
        }
        let remaining = (siteDocuments as? Set<SiteDocument>) ?? []
        for (index, file) in limited.enumerated() {
            if let id = file.id, let doc = remaining.first(where: { $0.id == id }) {
                doc.sortIndex = Int32(index)
                doc.filename = file.filename
                doc.contentType = file.contentType
                continue
            }
            let doc = SiteDocument(context: context ?? CoreDataManager.shared.context)
            doc.id = UUID()
            doc.filename = file.filename
            doc.contentType = file.contentType
            doc.data = file.data
            doc.userId = userId
            doc.sortIndex = Int32(index)
            doc.customer = self
        }
    }
}
