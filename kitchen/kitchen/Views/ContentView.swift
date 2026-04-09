import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.hasKitchen {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .appPageBackground()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
