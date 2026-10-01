import SwiftUI
import AppKit
import ClipboardHistoryCore

// Avoids @State, which needs the SwiftUI macro plugin bundled only with full
// Xcode — this machine builds with the Command Line Tools toolchain.
final class HoverBox: ObservableObject {
    @Published var isHovering = false
}

struct ClipboardRow: View {
    let item: ClipboardItem
    var onSelect: () -> Void
    var onDelete: () -> Void
    @StateObject private var hover = HoverBox()

    var body: some View {
        HStack(spacing: 8) {
            rowIcon
            Text(item.preview)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hover.isHovering ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(
            hover.isHovering ? .regular.tint(.primary.opacity(0.16)).interactive() : .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                // Fires on every mouse move; only act when the hover starts
                // so the preview (and any image decode) isn't redone each time.
                guard !hover.isHovering else { return }
                hover.isHovering = true
                showPreview()
            case .ended:
                hover.isHovering = false
                PreviewPanel.shared.hide()
            }
        }
        .animation(.easeOut(duration: 0.12), value: hover.isHovering)
        .help(item.hoverInfo())
    }

    private func showPreview() {
        switch item.kind {
        case .text:
            PreviewPanel.shared.show(text: item.text)
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                PreviewPanel.shared.show(image: nsImage)
            }
        case .file:
            // A Finder copy of an image file arrives as a file reference,
            // not image data — preview it from disk.
            if let path = item.filePaths?.first, PreviewPanel.isImageFile(path),
               let nsImage = NSImage(contentsOfFile: path) {
                PreviewPanel.shared.show(image: nsImage)
            }
        }
    }

    @ViewBuilder
    private var rowIcon: some View {
        switch item.kind {
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        case .file:
            if let firstPath = item.filePaths?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: firstPath))
                    .resizable()
                    .frame(width: 18, height: 18)
            }
        case .text:
            EmptyView()
        }
    }
}
