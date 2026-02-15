import UIKit

public struct StorageService: Sendable {
    public static let appGroupIdentifier = "group.com.genichihashi.snapwords"

    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        )
    }

    public init() {}

    public func saveScreenshot(image: UIImage) throws -> String {
        guard let containerURL else {
            throw StorageError.noContainer
        }

        let screenshotsDir = containerURL.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        let filename = UUID().uuidString + ".jpg"
        let fileURL = screenshotsDir.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }

        try data.write(to: fileURL)
        return fileURL.path
    }

    public func saveCrop(image: UIImage) throws -> String {
        guard let containerURL else {
            throw StorageError.noContainer
        }

        let cropsDir = containerURL.appendingPathComponent("crops", isDirectory: true)
        try FileManager.default.createDirectory(at: cropsDir, withIntermediateDirectories: true)

        let filename = UUID().uuidString + ".jpg"
        let fileURL = cropsDir.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }

        try data.write(to: fileURL)
        return fileURL.path
    }

    public func loadImage(at path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    public func deleteAllData() throws {
        guard let containerURL else { return }

        let screenshotsDir = containerURL.appendingPathComponent("screenshots")
        let cropsDir = containerURL.appendingPathComponent("crops")

        try? FileManager.default.removeItem(at: screenshotsDir)
        try? FileManager.default.removeItem(at: cropsDir)
    }
}

public enum StorageError: Error, LocalizedError {
    case noContainer
    case imageConversionFailed

    public var errorDescription: String? {
        switch self {
        case .noContainer: "App Group container not found"
        case .imageConversionFailed: "Failed to convert image to data"
        }
    }
}
