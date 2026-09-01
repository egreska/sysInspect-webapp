//
//  SiteDocumentFile.swift
//  Systems Inspector
//

import Foundation

struct SiteDocumentFile: Equatable {
    var id: UUID?
    var filename: String
    var contentType: String
    var data: Data
}
