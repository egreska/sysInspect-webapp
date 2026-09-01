//
//  ZipCodeLookup.swift
//  Systems Inspector
//

import Foundation

enum ZipCodeLookup {
    private static let table: [String: (city: String, state: String)] = [
        "10001": ("New York", "NY"),
        "90210": ("Beverly Hills", "CA"),
        "60601": ("Chicago", "IL"),
        "75201": ("Dallas", "TX"),
        "85001": ("Phoenix", "AZ"),
        "19102": ("Philadelphia", "PA"),
        "77001": ("Houston", "TX"),
        "98101": ("Seattle", "WA"),
        "80202": ("Denver", "CO"),
        "02101": ("Boston", "MA"),
    ]

    static func cityState(for fiveDigitZip: String) -> (city: String, state: String)? {
        table[fiveDigitZip]
    }
}
