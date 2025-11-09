//
//  ContentView.swift
//  CliniqueHarmony
//
//  Created by Ana Bogdan on 09.11.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        MainTabView()
            .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
