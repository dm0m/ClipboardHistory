import AppKit
import Testing
@testable import ClipboardHistory

struct PreviewPanelTests {
    private let bounds = NSSize(width: 320, height: 320)

    @Test func smallImageKeepsNaturalSize() {
        let size = PreviewPanel.fittedSize(for: NSSize(width: 100, height: 50), within: bounds)
        #expect(size == NSSize(width: 100, height: 50))
    }

    @Test func imageExactlyAtBoundsIsUnchanged() {
        let size = PreviewPanel.fittedSize(for: bounds, within: bounds)
        #expect(size == bounds)
    }

    @Test func wideImageIsLimitedByWidth() {
        let size = PreviewPanel.fittedSize(for: NSSize(width: 1600, height: 400), within: bounds)
        #expect(size == NSSize(width: 320, height: 80))
    }

    @Test func tallImageIsLimitedByHeight() {
        let size = PreviewPanel.fittedSize(for: NSSize(width: 300, height: 1200), within: bounds)
        #expect(size == NSSize(width: 80, height: 320))
    }

    @Test func largeSquareImageFillsBounds() {
        let size = PreviewPanel.fittedSize(for: NSSize(width: 2000, height: 2000), within: bounds)
        #expect(size == bounds)
    }

    @Test func scaledSizeIsRoundedToWholePoints() {
        let size = PreviewPanel.fittedSize(for: NSSize(width: 1000, height: 333), within: bounds)
        #expect(size == NSSize(width: 320, height: 107))
    }

    @Test func degenerateSizesFallBackToZero() {
        #expect(PreviewPanel.fittedSize(for: .zero, within: bounds) == .zero)
        #expect(PreviewPanel.fittedSize(for: NSSize(width: 100, height: 0), within: bounds) == .zero)
        #expect(PreviewPanel.fittedSize(for: NSSize(width: -10, height: 50), within: bounds) == .zero)
    }

    @Test func imageExtensionsAreImageFiles() {
        #expect(PreviewPanel.isImageFile("/Users/me/Desktop/Screenshot 2026-10-01 at 19.34.16.png"))
        #expect(PreviewPanel.isImageFile("/tmp/photo.JPG"))
        #expect(PreviewPanel.isImageFile("/tmp/photo.heic"))
        #expect(PreviewPanel.isImageFile("/tmp/scan.tiff"))
    }

    @Test func nonImageExtensionsAreNotImageFiles() {
        #expect(!PreviewPanel.isImageFile("/tmp/notes.txt"))
        #expect(!PreviewPanel.isImageFile("/tmp/report.pdf"))
        #expect(!PreviewPanel.isImageFile("/tmp/Folder"))
        #expect(!PreviewPanel.isImageFile("/tmp/archive.zip"))
    }
}
