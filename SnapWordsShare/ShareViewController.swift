import UIKit
import SwiftUI
import SwiftData
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

            showImportView(image: image)
        } catch {
            close()
        }
    }

    @MainActor
    private func showImportView(image: UIImage) {
        // Remove spinner
        view.subviews.forEach { $0.removeFromSuperview() }

        do {
            let container = try SharedModelContainer.create()

            let importView = ShareImportView(image: image) { [weak self] in
                self?.close()
            }
            .modelContainer(container)

            let hostingController = UIHostingController(rootView: importView)
            addChild(hostingController)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            hostingController.didMove(toParent: self)
        } catch {
            close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
