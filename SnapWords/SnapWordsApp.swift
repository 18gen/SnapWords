import SwiftUI
import SwiftData
import LensCore

@main
struct SnapWordsApp: App {
    let modelContainer: ModelContainer
    @State private var captureImage: UIImage?
    @State private var captureFilename: String?
    @State private var appLocale = AppLocale()
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkPendingImages()
                }
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
            service.removePending(filename: filename)
        }
    }

    /// Fallback: pick up any pending images left by the share extension
    /// when the app comes to foreground (in case the URL open failed).
    private func checkPendingImages() {
        guard captureImage == nil else { return }
        let service = PendingImageService()
        guard let filename = service.listPending().first,
              let image = service.loadPending(filename: filename) else { return }
        captureImage = image
        captureFilename = filename
        service.removePending(filename: filename)
    }
}
