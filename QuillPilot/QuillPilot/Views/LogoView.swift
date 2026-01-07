import Cocoa

/**
 * LogoView - Simple logo view for QuillPilot
 *
 * Loads feather.png from the project assets.
 */
class LogoView: NSView {

    // MARK: - Properties

    var logoSize: CGFloat = 96 {
        didSet { needsDisplay = true }
    }

    private var logoImage: NSImage?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    convenience init(size: CGFloat) {
        self.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        self.logoSize = size
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        loadLogo()
    }

    private func loadLogo() {
        if let img = NSImage.quillPilotFeatherImage() {
            logoImage = img
            logoImage?.isTemplate = false
        } else {
            // Fallback to app icon so we never render an empty header.
            logoImage = NSApp.applicationIconImage
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Clear background
        NSGraphicsContext.current?.saveGraphicsState()
        NSColor.clear.setFill()
        bounds.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        guard let image = logoImage else { return }

        let insetBounds = bounds.insetBy(dx: 4, dy: 4)

        // Aspect-fit the icon
        let imgSize = image.size
        var drawRect = insetBounds
        if imgSize.width > 0, imgSize.height > 0 {
            let scale = min(insetBounds.width / imgSize.width, insetBounds.height / imgSize.height)
            let w = imgSize.width * scale
            let h = imgSize.height * scale
            drawRect = NSRect(
                x: insetBounds.midX - w / 2,
                y: insetBounds.midY - h / 2,
                width: w,
                height: h
            )
        }

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    override var isOpaque: Bool {
        return false
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: logoSize, height: logoSize)
    }
}
