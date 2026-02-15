import UIKit

@Observable
final class ZoomController {
    weak var scrollView: UIScrollView?

    func zoomIn() {
        guard let sv = scrollView else { return }
        let newScale = min(sv.zoomScale * 1.5, sv.maximumZoomScale)
        sv.setZoomScale(newScale, animated: true)
    }

    func zoomOut() {
        guard let sv = scrollView else { return }
        let newScale = max(sv.zoomScale / 1.5, sv.minimumZoomScale)
        sv.setZoomScale(newScale, animated: true)
    }
}
