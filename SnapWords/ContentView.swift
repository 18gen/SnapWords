import SwiftUI
import UIKit

struct ContentView: View {
    @Binding var captureImage: UIImage?
    @Binding var captureFilename: String?
    @Environment(AppLocale.self) private var locale
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(locale("tab.words"), systemImage: "textformat.abc", value: 0) {
                WordsTabView(
                    captureImage: $captureImage,
                    captureFilename: $captureFilename
                )
            }

            Tab(locale("tab.review"), systemImage: "rectangle.stack", value: 1) {
                NavigationStack {
                    ReviewView()
                }
            }

            Tab(locale("tab.settings"), systemImage: "gear", value: 2) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onChange(of: captureImage) { _, newValue in
            if newValue != nil {
                selectedTab = 0
            }
        }
    }
}
