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
        "folder.fill",
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
        "#007AFF", // Blue
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#34C759", // Green
        "#5856D6", // Purple
        "#AF52DE", // Violet
        "#FF2D55", // Pink
        "#00C7BE", // Teal
        "#8E8E93", // Gray
    ]
}
