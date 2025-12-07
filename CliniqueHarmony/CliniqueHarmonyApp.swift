//
//  CliniqueHarmonyApp.swift
//  CliniqueHarmony
//
//  Created by Ana Bogdan on 09.11.2025.
//

import SwiftUI

@main
struct CliniqueHarmonyApp: App {
    // Initialize Core Data stack
    let persistenceController = PersistenceController.shared
    
    init() {
        // Seed initial data if needed
        Task { @MainActor in
            await DataSeeder.seedIfNeeded()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
