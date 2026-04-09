//
//  kitchenApp.swift
//  kitchen
//
//  Created by Cain on 2026/4/9.
//

import SwiftUI

@main
struct kitchenApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
