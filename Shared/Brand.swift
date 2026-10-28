import SwiftUI

extension Color {
    static let amber = Color(red: 0.96, green: 0.63, blue: 0.23)
    static let amberLight = Color(red: 1, green: 0.82, blue: 0.48)
    static let amberDark = Color(red: 0.94, green: 0.54, blue: 0.14)
}

/// The pixel "j" from the app icon.
struct PixelJ: View {
    var cell: CGFloat = 2

    private static let rows = ["...##", "...##", ".....", "...##", "...##", "...##", "...##", "...##", "...##", "##.##", ".###."]

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for (r, row) in Self.rows.enumerated() {
                for (c, ch) in row.enumerated() where ch == "#" {
                    path.addRect(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell))
                }
            }
            context.fill(path, with: .linearGradient(
                Gradient(colors: [.amberLight, .amberDark]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
        .frame(width: 5 * cell, height: 11 * cell)
    }
}

/// Rounded panel with an amber rim that catches light at the top-left, like the icon.
struct PanelChrome: ViewModifier {
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(.ultraThickMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.08)))
            .overlay(shape.strokeBorder(LinearGradient(
                stops: [
                    .init(color: .amberLight.opacity(0.8), location: 0),
                    .init(color: .amber.opacity(0), location: 0.35),
                    .init(color: .amber.opacity(0), location: 0.75),
                    .init(color: .amberDark.opacity(0.4), location: 1),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )))
            .clipShape(shape)
    }
}

/// A small key label, e.g. ↩ or esc.
struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.white.opacity(0.07), in: .rect(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.08)))
    }
}
