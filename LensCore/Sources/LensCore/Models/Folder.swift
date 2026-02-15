import Foundation
import SwiftData

@Model
public final class Folder {
    public var id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var createdAt: Date
    public var isSystem: Bool
    public var sortOrder: Int

    @Relationship(inverse: \Term.folder)
    public var terms: [Term]

    public var parent: Folder?

    @Relationship(inverse: \Folder.parent)
    public var children: [Folder]

    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "",
        colorHex: String = "#6B7B8D",
        isSystem: Bool = false,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.isSystem = isSystem
        self.sortOrder = isSystem ? 0 : 1
        self.terms = []
        self.parent = parent
        self.children = []
    }

    // MARK: - Computed Properties

    public var depth: Int {
        var d = 0
        var current = parent
        while let p = current {
            d += 1
            current = p.parent
        }
        return d
    }

    public var canAddSubfolder: Bool {
        depth < FolderConstants.maxNestingDepth - 1
    }

    public var allTermsRecursive: [Term] {
        var result = terms
        for child in children {
            result.append(contentsOf: child.allTermsRecursive)
        }
        return result
    }
}
