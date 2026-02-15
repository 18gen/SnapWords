import UIKit

public struct PendingImageService: Sendable {
    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: StorageService.appGroupIdentifier
        )
    }

    private var pendingDir: URL? {
        guard let containerURL else { return nil }
        return containerURL.appendingPathComponent("pending", isDirectory: true)
    }

    public init() {}

    /// Save an image as pending and return its filename (UUID-based).
    public func savePending(image: UIImage) throws -> String {
        guard let dir = pendingDir else { throw StorageError.noContainer }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = UUID().uuidString + ".jpg"
        let fileURL = dir.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageError.imageConversionFailed
        }
        try data.write(to: fileURL)
        return filename
    }

    /// List all pending image filenames, newest first.
    public func listPending() -> [String] {
        guard let dir = pendingDir else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }

        let jpgs = files.filter { $0.hasSuffix(".jpg") }
        return jpgs.sorted { a, b in
            let aDate = (try? fm.attributesOfItem(atPath: dir.appendingPathComponent(a).path)[.creationDate] as? Date) ?? .distantPast
            let bDate = (try? fm.attributesOfItem(atPath: dir.appendingPathComponent(b).path)[.creationDate] as? Date) ?? .distantPast
            return aDate > bDate
        }
    }

    /// Load a pending image by filename.
    public func loadPending(filename: String) -> UIImage? {
        guard let dir = pendingDir else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(filename).path)
    }

    /// Full path for a pending image.
    public func pendingPath(for filename: String) -> String? {
        guard let dir = pendingDir else { return nil }
        let path = dir.appendingPathComponent(filename).path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Remove a pending image after processing.
    public func removePending(filename: String) {
        guard let dir = pendingDir else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
    }
}
