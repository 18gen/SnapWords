import SwiftUI
import LensCore

struct FolderIcon: View {
    let iconName: String
    let colorHex: String
    var size: CGFloat = 40

    private var folderColor: Color { Color(hex: colorHex) }
    private var showIcon: Bool { !iconName.isEmpty }

    // Proportions
    private var width: CGFloat { size * 1.15 }
    private var height: CGFloat { size }
    private var cornerRadius: CGFloat { size * 0.1 }
    private var tabHeight: CGFloat { size * 0.22 }
    private var tabWidth: CGFloat { width * 0.42 }
    private var bodyTop: CGFloat { tabHeight * 0.5 }
    private var bodyHeight: CGFloat { height - bodyTop }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Back panel (tab) — noticeably darker
            FolderTabShape(
                tabWidth: tabWidth,
                tabHeight: tabHeight,
                cornerRadius: cornerRadius
            )
            .fill(
                LinearGradient(
                    colors: [
                        folderColor.mix(with: .black, by: 0.35),
                        folderColor.mix(with: .black, by: 0.45),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)

            // Front panel (body) — base color with subtle gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            folderColor.mix(with: .white, by: 0.08),
                            folderColor,
                            folderColor.mix(with: .black, by: 0.08),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: bodyHeight)
                .offset(y: bodyTop)

            // Top-edge highlight on body
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.15)
                    )
                )
                .frame(width: width, height: bodyHeight)
                .offset(y: bodyTop)

            // Icon badge — blended with folder color, not pure white
            if showIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(
                        folderColor.mix(with: .white, by: 0.45).opacity(0.7)
                    )
                    .frame(width: width, height: bodyHeight)
                    .offset(y: bodyTop)
            }
        }
        .frame(width: width, height: height)
    }
}

/// The back shape of the folder: a rectangle with a tab bump on the top-left.
private struct FolderTabShape: Shape {
    let tabWidth: CGFloat
    let tabHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let cr = cornerRadius
        let tw = tabWidth
        let th = tabHeight
        let curveW = cr * 1.2

        var p = Path()

        p.move(to: CGPoint(x: 0, y: cr))

        // Top-left corner of tab
        p.addArc(
            tangent1End: CGPoint(x: 0, y: 0),
            tangent2End: CGPoint(x: cr, y: 0),
            radius: cr
        )

        // Top edge of tab
        p.addLine(to: CGPoint(x: tw - cr, y: 0))

        // Top-right corner of tab curves down
        p.addArc(
            tangent1End: CGPoint(x: tw, y: 0),
            tangent2End: CGPoint(x: tw, y: cr),
            radius: cr
        )

        // Curve down from tab to body top level
        p.addLine(to: CGPoint(x: tw, y: th - cr))
        p.addQuadCurve(
            to: CGPoint(x: tw + curveW, y: th),
            control: CGPoint(x: tw, y: th)
        )

        // Body top edge to top-right corner
        p.addLine(to: CGPoint(x: rect.width - cr, y: th))
        p.addArc(
            tangent1End: CGPoint(x: rect.width, y: th),
            tangent2End: CGPoint(x: rect.width, y: th + cr),
            radius: cr
        )

        // Right edge
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - cr))

        // Bottom-right corner
        p.addArc(
            tangent1End: CGPoint(x: rect.width, y: rect.height),
            tangent2End: CGPoint(x: rect.width - cr, y: rect.height),
            radius: cr
        )

        // Bottom edge
        p.addLine(to: CGPoint(x: cr, y: rect.height))

        // Bottom-left corner
        p.addArc(
            tangent1End: CGPoint(x: 0, y: rect.height),
            tangent2End: CGPoint(x: 0, y: rect.height - cr),
            radius: cr
        )

        p.closeSubpath()
        return p
    }
}
