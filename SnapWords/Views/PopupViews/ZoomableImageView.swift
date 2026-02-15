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

        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableScrollView, context: Context) {
        if scrollView.imageView?.image !== image {
            scrollView.imageView?.image = image
            scrollView.zoomScale = 1.0
            scrollView.setNeedsLayout()
        }
        zoomController.scrollView = scrollView
    }

    func makeCoordinator() -> Coordinator { Coordinator(onVisibleRectChanged: onVisibleRectChanged) }

    class ZoomableScrollView: UIScrollView {
        weak var imageView: UIImageView?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let imageView else { return }
            // Fill width: image width = scroll view width, height scaled proportionally
            if let image = imageView.image, image.size.width > 0 {
                let scale = bounds.width / image.size.width
                let imageH = image.size.height * scale
                imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: imageH)
                contentSize = imageView.frame.size
            } else {
                imageView.frame = bounds
                contentSize = bounds.size
            }
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

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard scale > 1.0 else { return }
            reportVisibleRect(scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard scrollView.zoomScale > 1.0 else { return }
            reportVisibleRect(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate, scrollView.zoomScale > 1.0 else { return }
            reportVisibleRect(scrollView)
        }

        private func reportVisibleRect(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset
            let size = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            guard contentSize.width > 0, contentSize.height > 0 else { return }
            let rect = CGRect(
                x: offset.x / contentSize.width,
                y: offset.y / contentSize.height,
                width: size.width / contentSize.width,
                height: size.height / contentSize.height
            )
            onVisibleRectChanged?(rect)
        }
    }
}
