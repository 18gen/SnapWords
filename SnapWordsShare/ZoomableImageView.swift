import SwiftUI

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let zoomController: ZoomController
    var onVisibleRectChanged: ((CGRect) -> Void)?

    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        scrollView.imageView = imageView
        scrollView.addSubview(imageView)

        zoomController.scrollView = scrollView
        scrollView.coordinator = context.coordinator

        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableScrollView, context: Context) {
        if scrollView.imageView?.image !== image {
            scrollView.imageView?.image = image
            scrollView.zoomScale = 1.0
            scrollView.lastBoundsSize = .zero
            scrollView.setNeedsLayout()
        }
        zoomController.scrollView = scrollView
    }

    func makeCoordinator() -> Coordinator { Coordinator(onVisibleRectChanged: onVisibleRectChanged) }

    class ZoomableScrollView: UIScrollView {
        weak var imageView: UIImageView?
        weak var coordinator: Coordinator?
        var lastBoundsSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let imageView else { return }

            // Only recalculate base frame when bounds actually change
            // (first layout, rotation, container resize).
            // During zoom, bounds.size stays the same — skip to avoid
            // fighting the zoom transform.
            if bounds.size != lastBoundsSize {
                lastBoundsSize = bounds.size
                if let image = imageView.image, image.size.width > 0 {
                    let scale = bounds.width / image.size.width
                    let imageH = image.size.height * scale
                    imageView.frame = CGRect(origin: .zero,
                        size: CGSize(width: bounds.width, height: imageH))
                    contentSize = imageView.frame.size
                    zoomScale = 1.0
                } else {
                    imageView.frame = bounds
                    contentSize = bounds.size
                }
            }

            centerImageView()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.coordinator?.reportVisibleRect(self)
            }
        }

        func centerImageView() {
            guard let imageView else { return }
            let xOffset = max(0, (bounds.width - contentSize.width) / 2)
            let yOffset = max(0, (bounds.height - contentSize.height) / 2)
            imageView.frame.origin = CGPoint(x: xOffset, y: yOffset)
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var onVisibleRectChanged: ((CGRect) -> Void)?

        init(onVisibleRectChanged: ((CGRect) -> Void)?) {
            self.onVisibleRectChanged = onVisibleRectChanged
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomableScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomableScrollView)?.centerImageView()
            reportVisibleRect(scrollView)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            reportVisibleRect(scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            reportVisibleRect(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else { return }
            reportVisibleRect(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportVisibleRect(scrollView)
        }

        func reportVisibleRect(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset
            let size = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            guard contentSize.width > 0, contentSize.height > 0 else { return }
            let rect = CGRect(
                x: max(0, offset.x / contentSize.width),
                y: max(0, offset.y / contentSize.height),
                width: min(1, size.width / contentSize.width),
                height: min(1, size.height / contentSize.height)
            )
            onVisibleRectChanged?(rect)
        }
    }
}
