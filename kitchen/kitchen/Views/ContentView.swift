import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isBootstrapping {
                Color.clear
            } else if store.hasKitchen {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .appPageBackground()
        .task {
            await store.bootstrap()
        }
        .task(id: store.kitchen?.id) {
            if store.kitchen != nil {
                await store.fetchAll()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
