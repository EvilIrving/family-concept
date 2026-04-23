//
//  kitchenApp.swift
//  kitchen
//
//  Created by Cain on 2026/4/9.
//

import Nuke
import SwiftUI

@main
struct kitchenApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var feedbackRouter = AppFeedbackRouter.shared

    init() {
        Self.configureImagePipeline()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(feedbackRouter)
                .preferredColorScheme(store.colorScheme)
        }
    }

    private static func configureImagePipeline() {
        let dataCache = try? DataCache(name: "cooklist.dish-images")
        dataCache?.sizeLimit = 200 * 1024 * 1024

        let imageCache = ImageCache()
        imageCache.costLimit = 120 * 1024 * 1024
        imageCache.countLimit = 240

        ImagePipeline.shared = ImagePipeline {
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.isTaskCoalescingEnabled = true
        }
    }
}
