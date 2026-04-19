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
    @StateObject private var toastQueue = ToastQueue.shared
    @StateObject private var bbQueue = BBQueue.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(toastQueue)
                .environmentObject(bbQueue)
                .preferredColorScheme(store.colorScheme)
        }
    }
}
