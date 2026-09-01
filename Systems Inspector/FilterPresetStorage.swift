//
//  FilterPresetStorage.swift
//  Systems Inspector
//
//  Manages saved filter presets for reports.
//

import Foundation

struct FilterPreset: Codable {
    let name: String
    let filters: [Filter]
}

enum FilterPresetStorage {
    private static let key = "reportFilterPresets"
    
    static func load() -> [FilterPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let presets = try? JSONDecoder().decode([FilterPreset].self, from: data) else {
            return []
        }
        return presets
    }
    
    static func save(_ presets: [FilterPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    static func add(_ preset: FilterPreset) {
        var list = load()
        list.append(preset)
        save(list)
    }
    
    static func delete(at index: Int) {
        var list = load()
        guard index >= 0, index < list.count else { return }
        list.remove(at: index)
        save(list)
    }
}
