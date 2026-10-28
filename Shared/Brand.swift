import SwiftUI

extension Color {
    static let amber = Color(red: 0.96, green: 0.63, blue: 0.23)
    static let amberLight = Color(red: 1, green: 0.82, blue: 0.48)
    static let amberDark = Color(red: 0.94, green: 0.54, blue: 0.14)
}

/// The pixel "j" from the app icon.
struct PixelJ: View {
    var cell: CGFloat = 2

    var body: some View { PixelText("j", cell: cell) }
}

/// Lowercase pixel lettering in the style of the icon's "j", with the same amber gradient.
struct PixelText: View {
    let text: String
    var cell: CGFloat = 2

    init(_ text: String, cell: CGFloat = 2) {
        self.text = text
        self.cell = cell
    }

    /// 11 rows: ascender 0–2, x-height 3–8, descender 9–10. Strokes are 2 cells wide.
    private static let glyphs: [Character: [String]] = [
        "j": ["...##", "...##", ".....", "...##", "...##", "...##", "...##", "...##", "...##", "##.##", ".###."],
        "m": ["........", "........", "........", "#######.", "########", "##.##.##", "##.##.##", "##.##.##", "##.##.##", "........", "........"],
        "y": [".....", ".....", ".....", "##.##", "##.##", "##.##", "##.##", "##.##", ".####", "...##", "####."],
        "o": [".....", ".....", ".....", ".###.", "##.##", "##.##", "##.##", "##.##", ".###.", ".....", "....."],
        "t": ["....", ".##.", ".##.", "####", ".##.", ".##.", ".##.", ".##.", "..##", "....", "...."],
        "s": [".....", ".....", ".....", ".####", "##...", ".###.", "...##", "...##", "####.", ".....", "....."],
        " ": ["...", "...", "...", "...", "...", "...", "...", "...", "...", "...", "..."],
    ]

    private var glyphs: [[String]] { text.lowercased().compactMap { Self.glyphs[$0] } }
    /// Glyph widths plus one empty column between letters.
    private var columns: Int { glyphs.reduce(0) { $0 + $1[0].count } + max(glyphs.count - 1, 0) }

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = 0
            for glyph in glyphs {
                for (r, row) in glyph.enumerated() {
                    for (c, ch) in row.enumerated() where ch == "#" {
                        path.addRect(CGRect(x: CGFloat(x + c) * cell, y: CGFloat(r) * cell, width: cell, height: cell))
                    }
                }
                x += glyph[0].count + 1
            }
            context.fill(path, with: .linearGradient(
                Gradient(colors: [.amberLight, .amberDark]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
        .frame(width: CGFloat(columns) * cell, height: 11 * cell)
        .accessibilityLabel(text)
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
