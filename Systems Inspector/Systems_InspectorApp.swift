//
//  Systems_InspectorApp.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/21/25.
//

import SwiftUI

@main
struct Systems_InspectorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
