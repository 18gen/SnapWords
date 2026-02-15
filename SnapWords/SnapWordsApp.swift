import SwiftUI
import SwiftData
import LensCore

@main
struct SnapWordsApp: App {
    let modelContainer: ModelContainer
    @State private var captureImage: UIImage?
    @State private var captureFilename: String?
    @State private var appLocale = AppLocale()

    init() {
        do {
            let container = try SharedModelContainer.create()
            modelContainer = container
            FolderBootstrap.ensureUnfiledFolder(in: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                captureImage: $captureImage,
                captureFilename: $captureFilename
            )
            .environment(appLocale)
            .onOpenURL { url in
                handleURL(url)
            }
        }
        .modelContainer(modelContainer)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "snapwords", url.host == "capture" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let filename = components?.queryItems?.first(where: { $0.name == "image" })?.value else {
            return
        }

        let service = PendingImageService()
        if let image = service.loadPending(filename: filename) {
            captureImage = image
            captureFilename = filename
        }
    }
}
