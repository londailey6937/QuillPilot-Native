import Cocoa

/**
 * AnimatedLogoView - Static feather logo for Quill Pilot
 *
 * Features:
 * - Loads feather.png image
 * - Black background replaced with transparency
 */
class AnimatedLogoView: NSView {

    // MARK: - Properties

    var logoSize: CGFloat = 96 {
        didSet { needsDisplay = true }
    }

    var animate: Bool = true  // Kept for API compatibility

    private var featherImage: NSImage?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    convenience init(size: CGFloat, animate: Bool = true) {
        self.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        self.logoSize = size
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        loadFeatherImage()
    }

    private func loadFeatherImage() {
        // Try multiple ways to load the image
        var image: NSImage?

        // Try from asset catalog
        image = NSImage(named: "FeatherLogo")

        // Try from bundle resource
        if image == nil {
            image = Bundle.main.image(forResource: "feather")
        }

        // Try direct file path as fallback
        if image == nil {
            let path = "/Users/londailey/QuillPilot/QuillPilot/QuillPilot/Assets.xcassets/FeatherLogo.imageset/feather.png"
            image = NSImage(contentsOfFile: path)
        }

        if let img = image {
            featherImage = makeBlackTransparent(in: img)
            needsDisplay = true
        }
    }

    private func makeBlackTransparent(in image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelBuffer = context.data else {
            return image
        }

        let pixels = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        // Make black/dark pixels transparent
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixels[offset]
                let g = pixels[offset + 1]
                let b = pixels[offset + 2]

                // Check if pixel is dark (near black) - threshold of 50
                let threshold: UInt8 = 50
                if r < threshold && g < threshold && b < threshold {
                    pixels[offset + 3] = 0  // Set alpha to 0 (transparent)
                }
            }
        }

        guard let processedCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: processedCGImage, size: NSSize(width: width, height: height))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let image = featherImage {
            let insetBounds = bounds.insetBy(dx: 4, dy: 4)
            image.draw(in: insetBounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: logoSize, height: logoSize)
    }
}
