import UIKit
import UniformTypeIdentifiers
import LensCore

@objc(ShareViewController)
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        Task { @MainActor in
            await handleSharedImage()
        }
    }

    @MainActor
    private func handleSharedImage() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            close()
            return
        }

        let imageType = UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(imageType) else {
            close()
            return
        }

        do {
            let loadedItem = try await provider.loadItem(forTypeIdentifier: imageType, options: nil)

            var image: UIImage?
            if let url = loadedItem as? URL, let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
            } else if let data = loadedItem as? Data {
                image = UIImage(data: data)
            } else if let img = loadedItem as? UIImage {
                image = img
            }

            guard let image else {
                close()
                return
            }

            let service = PendingImageService()
            let filename = try service.savePending(image: image)

            guard let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "snapwords://capture?image=\(encoded)") else {
                close()
                return
            }

            openContainingApp(url: url)
            // Give the URL open time to fire before completing the extension
            try? await Task.sleep(for: .milliseconds(500))
        } catch {
            // Failed to save; just close
        }

        close()
    }

    @MainActor
    private func openContainingApp(url: URL) {
        // Use the simpler openURL: selector which is more reliable in extensions
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self as UIResponder
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
