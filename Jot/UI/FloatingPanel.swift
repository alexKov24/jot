import AppKit
import SwiftUI

/// Spotlight-style panel: floats over every Space. Borderless ones take keyboard focus without activating the app.
final class FloatingPanel: NSPanel {
    private let closesOnResign: Bool

    init(closesOnResign: Bool, titled: Bool, content: some View) {
        self.closesOnResign = closesOnResign
        let hosting = NSHostingView(rootView: content)
        super.init(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            // Titled panels activate the app, so the traffic lights show in colour.
            styleMask: titled ? [.titled, .closable, .fullSizeContentView] : [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        if titled {
            // Traffic lights over the SwiftUI content; drag the window by its top bar.
            titleVisibility = .hidden
            titlebarAppearsTransparent = true
            // An empty toolbar makes the bar taller, centring the traffic lights on the header row.
            toolbar = NSToolbar()
            toolbarStyle = .unified
            // No title bar inset, so the content (and window) keep their own size.
            hosting.safeAreaRegions = []
        }
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The SwiftUI content draws its own rounded background and rim.
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // Titled panels move by the title bar, so dragging content (like cards) stays free.
        isMovableByWindowBackground = !titled
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        contentView = hosting
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
/// A panel with an `autosave` name gets a title bar and reopens where it was left.
@MainActor
final class PanelController {
    private let closesOnResign: Bool
    private let autosave: String?
    private let content: (_ close: @escaping () -> Void) -> AnyView
    private var panel: FloatingPanel?

    init(closesOnResign: Bool, autosave: String? = nil, @ViewBuilder content: @escaping (_ close: @escaping () -> Void) -> some View) {
        self.closesOnResign = closesOnResign
        self.autosave = autosave
        self.content = { AnyView(content($0)) }
    }

    func toggle() {
        if panel?.isVisible == true { panel?.close() } else { show() }
    }

    func show() {
        panel?.close()
        // Free the autosave name; AppKit allows it on one window at a time.
        panel?.setFrameAutosaveName("")
        let panel = FloatingPanel(closesOnResign: closesOnResign, titled: autosave != nil, content: content { [weak self] in self?.panel?.close() })
        let size = panel.frame.size
        if let autosave, panel.setFrameUsingName(autosave) {
            // Keep only the saved top-left corner; the size comes from the content.
            panel.setFrame(NSRect(x: panel.frame.minX, y: panel.frame.maxY - size.height, width: size.width, height: size.height), display: false)
        } else if let screen = NSScreen.main?.visibleFrame {
            // Upper third of the active screen, like Spotlight.
            panel.setFrameOrigin(NSPoint(x: screen.midX - size.width / 2, y: screen.minY + screen.height * 0.68 - size.height / 2))
        }
        if let autosave { panel.setFrameAutosaveName(autosave) }
        if autosave != nil { NSApp.activate() }
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}
