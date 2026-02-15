import Foundation
import SwiftData

public enum SharedModelContainer {
    public static func create() throws -> ModelContainer {
        let schema = Schema([Term.self, Occurrence.self, Sense.self, Folder.self])

        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: StorageService.appGroupIdentifier
        )

        let storeURL: URL
        if let containerURL {
            storeURL = containerURL.appendingPathComponent("snapwords-v2.store")
        } else {
            // Fallback for simulator / missing entitlement
            storeURL = URL.applicationSupportDirectory.appendingPathComponent("snapwords-v2.store")
        }

        let config = ModelConfiguration(
            "SnapWords",
            schema: schema,
            url: storeURL
        )

        return try ModelContainer(for: schema, configurations: [config])
    }
}
