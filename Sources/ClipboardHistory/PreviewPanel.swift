import AppKit
import UniformTypeIdentifiers

/// A plain, opaque panel shown beside the app's window with a larger
/// preview of the hovered row: the full text of a text item, or the image
/// of an image item. Deliberately a native NSPanel rather than a SwiftUI
/// overlay: SwiftUI's `.glassEffect()` on this OS build composites outside
/// normal view z-ordering, which made an in-window floating preview
/// unreliable. A separate window sidesteps that entirely.
///
/// Styled to match the main popover (`ClipboardMenuView`): same corner
/// radius (26pt) and a subtle edge stroke standing in for the Liquid Glass
/// border. Colors are resolved from the host window's *current* appearance
/// each time the panel is shown (rather than fixed literals), so it tracks
/// the app's Light/Dark/System setting instead of always looking dark.
@MainActor
final class PreviewPanel {
    static let shared = PreviewPanel()

    private static let cornerRadius: CGFloat = 26
    private static let padding: CGFloat = 12
    private static let maxTextWidth: CGFloat = 260
    static let maxImageSize = NSSize(width: 320, height: 320)

    private let panel: NSPanel
    private let textField: NSTextField
    private let imageView: NSImageView
    private let content: NSView
    /// Observers on the host window that hide the panel when it goes away.
    /// Clicking a row closes the popover out from under the cursor, so the
    /// row never receives a hover `.ended` — without these the panel would
    /// be left floating on screen.
    private var hostObservers: [NSObjectProtocol] = []

    private init() {
        textField = NSTextField(wrappingLabelWithString: "")
        textField.font = .systemFont(ofSize: 12.5)
        textField.backgroundColor = .clear
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = false

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false

        content = NSView()
        content.wantsLayer = true
        content.layer?.cornerRadius = Self.cornerRadius
        content.layer?.borderWidth = 1
        content.addSubview(textField)
        content.addSubview(imageView)
        panel.contentView = content
    }

    func show(text: String) {
        guard let hostWindow = NSApp.keyWindow else { return }
        applyAppearance(of: hostWindow)

        let padding = Self.padding
        let maxWidth = Self.maxTextWidth
        textField.stringValue = text
        textField.preferredMaxLayoutWidth = maxWidth
        let fitting = textField.sizeThatFits(NSSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textField.frame = NSRect(x: padding, y: padding, width: maxWidth, height: fitting.height)
        textField.isHidden = false
        imageView.isHidden = true
        imageView.image = nil

        present(contentSize: NSSize(width: maxWidth, height: fitting.height), beside: hostWindow)
    }

    func show(image: NSImage) {
        guard let hostWindow = NSApp.keyWindow else { return }
        applyAppearance(of: hostWindow)

        let size = Self.fittedSize(for: image.size, within: Self.maxImageSize)
        imageView.image = image
        imageView.frame = NSRect(origin: NSPoint(x: Self.padding, y: Self.padding), size: size)
        imageView.isHidden = false
        textField.isHidden = true

        present(contentSize: size, beside: hostWindow)
    }

    func hide() {
        removeHostObservers()
        panel.orderOut(nil)
    }

    /// Scales `size` down to fit inside `bounds`, preserving aspect ratio.
    /// Never scales up, so small images show at their natural size.
    /// Degenerate (zero or negative) sizes fall back to `.zero`.
    nonisolated static func fittedSize(for size: NSSize, within bounds: NSSize) -> NSSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, bounds.width / size.width, bounds.height / size.height)
        return NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    /// Whether `path`'s extension names an image type, judged by extension
    /// alone so it never touches the disk.
    nonisolated static func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image)
    }

    /// Match the host window's actual current appearance (it may be pinned
    /// to Light/Dark or following System) so dynamic system colors below
    /// resolve to the same values the popover itself uses.
    private func applyAppearance(of hostWindow: NSWindow) {
        let appearance = hostWindow.effectiveAppearance
        panel.appearance = appearance
        appearance.performAsCurrentDrawingAppearance {
            content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            content.layer?.borderColor = NSColor.separatorColor.cgColor
            textField.textColor = .labelColor
        }
    }

    private func present(contentSize: NSSize, beside hostWindow: NSWindow) {
        let padding = Self.padding
        let panelSize = NSSize(width: contentSize.width + padding * 2, height: contentSize.height + padding * 2)
        let hostFrame = hostWindow.frame
        let origin = NSPoint(x: hostFrame.minX - panelSize.width - 8, y: hostFrame.maxY - panelSize.height)

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: false)
        panel.orderFront(nil)
        observe(hostWindow)
    }

    private func observe(_ hostWindow: NSWindow) {
        removeHostObservers()
        let center = NotificationCenter.default
        hostObservers = [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification].map { name in
            center.addObserver(forName: name, object: hostWindow, queue: .main) { _ in
                MainActor.assumeIsolated { PreviewPanel.shared.hide() }
            }
        }
    }

    private func removeHostObservers() {
        hostObservers.forEach(NotificationCenter.default.removeObserver)
        hostObservers = []
    }
}
