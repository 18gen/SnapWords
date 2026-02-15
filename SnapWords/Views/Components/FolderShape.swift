import SwiftUI

/// A folder silhouette shape matching the macOS/GoodNotes folder style.
struct FolderShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // Proportions
        let tabWidth = w * 0.42
        let tabHeight = h * 0.18
        let bodyTop = tabHeight
        let cornerRadius: CGFloat = w * 0.06
        let tabCornerRadius: CGFloat = w * 0.05

        var path = Path()

        // Start at bottom-left corner
        path.move(to: CGPoint(x: cornerRadius, y: h))
        // Bottom edge
        path.addLine(to: CGPoint(x: w - cornerRadius, y: h))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: w, y: h - cornerRadius),
            control: CGPoint(x: w, y: h)
        )
        // Right edge
        path.addLine(to: CGPoint(x: w, y: bodyTop + cornerRadius))
        // Top-right corner of body
        path.addQuadCurve(
            to: CGPoint(x: w - cornerRadius, y: bodyTop),
            control: CGPoint(x: w, y: bodyTop)
        )
        // Top edge of body (right of tab)
        path.addLine(to: CGPoint(x: tabWidth + tabCornerRadius, y: bodyTop))
        // Tab right curve (down from tab to body)
        path.addQuadCurve(
            to: CGPoint(x: tabWidth - tabCornerRadius, y: 0 + tabCornerRadius),
            control: CGPoint(x: tabWidth, y: 0)
        )
        // Tab top edge
        path.addLine(to: CGPoint(x: tabCornerRadius, y: tabCornerRadius))
        // Tab top-left corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: tabCornerRadius + tabCornerRadius),
            control: CGPoint(x: 0, y: tabCornerRadius)
        )
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: h - cornerRadius))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: h),
            control: CGPoint(x: 0, y: h)
        )

        return path
    }
}

/// The top flap area of the folder (slightly darker overlay).
struct FolderFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let tabHeight = h * 0.18
        let bodyTop = tabHeight
        let flapBottom = bodyTop + h * 0.08
        let cornerRadius: CGFloat = w * 0.06

        var path = Path()

        // Flap covers just the top strip of the body
        path.move(to: CGPoint(x: 0, y: bodyTop))
        path.addLine(to: CGPoint(x: w, y: bodyTop))
        // Top-right of body
        path.addLine(to: CGPoint(x: w, y: bodyTop))
        // Right edge down to flap bottom
        path.addLine(to: CGPoint(x: w, y: flapBottom))
        // Across bottom of flap
        path.addLine(to: CGPoint(x: 0, y: flapBottom))
        path.closeSubpath()

        // Clip to folder body area (round the top corners)
        var clip = Path()
        clip.move(to: CGPoint(x: 0, y: bodyTop))
        clip.addLine(to: CGPoint(x: w - cornerRadius, y: bodyTop))
        clip.addQuadCurve(
            to: CGPoint(x: w, y: bodyTop + cornerRadius),
            control: CGPoint(x: w, y: bodyTop)
        )
        clip.addLine(to: CGPoint(x: w, y: flapBottom))
        clip.addLine(to: CGPoint(x: 0, y: flapBottom))
        clip.closeSubpath()

        return clip
    }
}
