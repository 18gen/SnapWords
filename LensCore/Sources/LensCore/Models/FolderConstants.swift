import Foundation

public enum FolderConstants {
    // MARK: - Unfiled System Folder

    public static let unfiledFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let unfiledFolderName = "Unfiled"
    public static let unfiledFolderIcon = "tray.fill"
    public static let unfiledFolderColor = "#8E8E93"

    // MARK: - Nesting

    public static let maxNestingDepth = 3

    // MARK: - Icons

    public static let icons: [String] = [
        "",              // None (no icon)
        "book.fill",
        "star.fill",
        "heart.fill",
        "flame.fill",
        "bolt.fill",
        "leaf.fill",
        "globe.americas.fill",
        "graduationcap.fill",
        "briefcase.fill",
        "house.fill",
        "cart.fill",
        "fork.knife",
        "airplane",
        "car.fill",
        "sportscourt.fill",
        "music.note",
        "film.fill",
        "paintbrush.fill",
        "wrench.fill",
        "stethoscope.fill",
        "building.2.fill",
        "person.2.fill",
        "bubble.left.fill",
    ]

    public static let colors: [String] = [
        "#6B7B8D", // Gray-blue
        "#4A7FBD", // Muted blue
        "#C75450", // Muted red
        "#D4864A", // Muted orange
        "#C4A94D", // Muted gold
        "#5A9E6F", // Muted green
        "#7B6BA5", // Muted purple
        "#9B6BB5", // Muted violet
        "#C74E6E", // Muted rose
        "#4EA8A2", // Muted teal
    ]
}
