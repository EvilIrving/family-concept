import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsLaunchOnboardingDemo = true

    var body: some View {
        Group {
            if store.hasKitchen && showsLaunchOnboardingDemo {
                OnboardingView {
                    showsLaunchOnboardingDemo = false
                }
            } else if store.hasKitchen {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .appPageBackground()
        .onChange(of: store.hasKitchen) { _, hasKitchen in
            if hasKitchen {
                showsLaunchOnboardingDemo = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
