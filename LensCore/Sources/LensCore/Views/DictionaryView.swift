import SwiftUI
import UIKit

public struct DictionaryView: UIViewControllerRepresentable {
    public let term: String

    public init(term: String) {
        self.term = term
    }

    public func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    public func updateUIViewController(_ vc: UIReferenceLibraryViewController, context: Context) {}
}
