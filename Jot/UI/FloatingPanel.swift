import AppKit
import SwiftUI

/// Spotlight-style panel: floats over every Space, takes keyboard focus without activating the app.
final class FloatingPanel: NSPanel {
    private let closesOnResign: Bool

    init(size: NSSize, closesOnResign: Bool, content: some View) {
        self.closesOnResign = closesOnResign
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { standardWindowButton($0)?.isHidden = true }
        contentView = NSHostingView(rootView: content.ignoresSafeArea())
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        if closesOnResign { close() }
    }

    /// Esc
    override func cancelOperation(_ sender: Any?) { close() }
}

/// Builds a fresh panel on each show, so text fields start empty and focused.
@MainActor
final class PanelController {
    private let size: NSSize
    private let closesOnResign: Bool
    private let content: (_ close: @escaping () -> Void) -> AnyView
    private var panel: FloatingPanel?

    init(size: NSSize, closesOnResign: Bool, @ViewBuilder content: @escaping (_ close: @escaping () -> Void) -> some View) {
        self.size = size
        self.closesOnResign = closesOnResign
        self.content = { AnyView(content($0)) }
    }

    func toggle() {
        if panel?.isVisible == true { panel?.close() } else { show() }
    }

    func show() {
        panel?.close()
        let panel = FloatingPanel(size: size, closesOnResign: closesOnResign, content: content { [weak self] in self?.panel?.close() })
        if let screen = NSScreen.main?.visibleFrame {
            // Upper third of the active screen, like Spotlight.
            panel.setFrameOrigin(NSPoint(x: screen.midX - size.width / 2, y: screen.minY + screen.height * 0.68 - size.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}
