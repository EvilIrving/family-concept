import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isBootstrapping {
                LaunchScreenView()
                    .transition(.opacity)
            } else if store.hasKitchen {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .appPageBackground()
        .appToastHost()
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
