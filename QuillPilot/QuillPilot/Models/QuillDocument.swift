//
//  QuillDocument.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// QuillPilot's native document format (.quill)
/// Uses a macOS Document Package (folder presented as single file)
///
/// Package structure:
/// MyDocument.quill/
/// ├── document.json      (metadata + styles)
/// ├── text.rtf           (rich text content without images)
/// ├── images/            (extracted images as PNG)
/// │   ├── image_001.png
/// │   └── image_002.png
/// └── metadata.plist     (optional extended metadata)
struct QuillDocument {

    // MARK: - Metadata

    struct Metadata: Codable {
        let version: String
        var title: String
        let created: Date
        var modified: Date
        var wordCount: Int
        var author: String?
        var notes: String?

        init(title: String, wordCount: Int, author: String? = nil) {
            self.version = "2.0"  // Package format version
            self.title = title
            self.created = Date()
            self.modified = Date()
            self.wordCount = wordCount
            self.author = author
        }
    }

    // MARK: - Image Reference

    struct ImageReference: Codable {
        let id: String           // e.g., "image_001"
        let filename: String     // e.g., "image_001.png"
        let width: CGFloat
        let height: CGFloat
        let originalPosition: Int  // Character index in text
    }

    // MARK: - Document Data

    struct DocumentData: Codable {
        let metadata: Metadata
        let styles: [String: StyleDefinition]
        let images: [ImageReference]
    }

    let metadata: Metadata
    let attributedString: NSAttributedString
    let styles: [String: StyleDefinition]

    // MARK: - Static File Names

    private static let documentJsonFilename = "document.json"
    private static let textRtfFilename = "text.rtf"
    private static let imagesFolderName = "images"

    // MARK: - Save (Encode) to Package

    /// Save a QuillPilot document to a .quill package directory
    static func save(
        attributedString: NSAttributedString,
        title: String,
        styles: [String: StyleDefinition],
        to url: URL
    ) throws {
        let fileManager = FileManager.default

        // Create package directory (removing existing if present)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        // Extract images and create RTF without embedded images
        let (textOnlyAttributed, imageRefs, imageDataMap) = extractImages(from: attributedString)

        // Create images folder if we have images
        if !imageDataMap.isEmpty {
            let imagesURL = url.appendingPathComponent(imagesFolderName)
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)

            // Save each image as PNG
            for (filename, data) in imageDataMap {
                let imageURL = imagesURL.appendingPathComponent(filename)
                try data.write(to: imageURL)
            }
        }

        // Create metadata
        let wordCount = attributedString.string.split(separator: " ").count
        let metadata = Metadata(title: title.isEmpty ? "Untitled" : title, wordCount: wordCount)

        // Create document.json
        let documentData = DocumentData(
            metadata: metadata,
            styles: styles,
            images: imageRefs
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(documentData)
        let jsonURL = url.appendingPathComponent(documentJsonFilename)
        try jsonData.write(to: jsonURL)

        // Create text.rtf (without images, but with placeholders)
        let rtfURL = url.appendingPathComponent(textRtfFilename)
        let rtfData = try textOnlyAttributed.data(
            from: NSRange(location: 0, length: textOnlyAttributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        try rtfData.write(to: rtfURL)

        NSLog("✅ QuillDocument saved as package: \(url.lastPathComponent)")
    }

    // MARK: - Load (Decode) from Package

    /// Load a QuillPilot document from a .quill package directory
    static func load(from url: URL) throws -> QuillDocument {
        let fileManager = FileManager.default

        // Read document.json
        let jsonURL = url.appendingPathComponent(documentJsonFilename)
        guard fileManager.fileExists(atPath: jsonURL.path) else {
            throw QuillDocumentError.missingDocumentJson
        }

        let jsonData = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let documentData = try decoder.decode(DocumentData.self, from: jsonData)

        // Read text.rtf
        let rtfURL = url.appendingPathComponent(textRtfFilename)
        guard fileManager.fileExists(atPath: rtfURL.path) else {
            throw QuillDocumentError.missingTextRtf
        }

        var attributedString = try NSAttributedString(
            url: rtfURL,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )

        // Re-embed images from the images folder
        let imagesURL = url.appendingPathComponent(imagesFolderName)
        if fileManager.fileExists(atPath: imagesURL.path) {
            attributedString = try reembedImages(
                into: attributedString,
                imageRefs: documentData.images,
                imagesFolder: imagesURL
            )
        }

        return QuillDocument(
            metadata: documentData.metadata,
            attributedString: attributedString,
            styles: documentData.styles
        )
    }

    // MARK: - Legacy Support (ZIP-based .quill files)

    /// Attempt to load a legacy ZIP-based .quill file
    static func loadLegacy(from url: URL) throws -> QuillDocument {
        // Check if it's a directory (new format) or file (old ZIP format)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            // New package format
            return try load(from: url)
        }

        // Try legacy ZIP format
        let data = try Data(contentsOf: url)

        // Check for ZIP signature
        guard data.count >= 4,
              data[0] == 0x50, data[1] == 0x4b, data[2] == 0x03, data[3] == 0x04 else {
            throw QuillDocumentError.invalidFormat
        }

        // Extract metadata from legacy ZIP
        let metadataJSON = try extractFromLegacyZip(data: data, filename: "quill.json")

        let decoder = JSONDecoder()
        let legacyMetadata = try decoder.decode(LegacyMetadataFile.self, from: metadataJSON)

        // Reconstruct RTFD from legacy ZIP
        var fileWrappers: [String: FileWrapper] = [:]
        let allFilenames = try listFilesInLegacyZip(data: data)

        for filename in allFilenames where filename.hasPrefix("content.rtfd/") {
            let shortName = String(filename.dropFirst("content.rtfd/".count))
            if let fileData = try? extractFromLegacyZip(data: data, filename: filename) {
                let wrapper = FileWrapper(regularFileWithContents: fileData)
                wrapper.preferredFilename = shortName
                fileWrappers[shortName] = wrapper
            }
        }

        let rtfdWrapper = FileWrapper(directoryWithFileWrappers: fileWrappers)

        guard let rtfdData = rtfdWrapper.serializedRepresentation else {
            throw QuillDocumentError.invalidFormat
        }

        let attributedString = try NSAttributedString(
            data: rtfdData,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )

        return QuillDocument(
            metadata: legacyMetadata.metadata,
            attributedString: attributedString,
            styles: legacyMetadata.styles
        )
    }

    // MARK: - Image Extraction

    /// Extract images from attributed string, converting to PNG
    /// Returns: (text-only attributed string, image references, image data map)
    private static func extractImages(
        from attributed: NSAttributedString
    ) -> (NSAttributedString, [ImageReference], [String: Data]) {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        var imageRefs: [ImageReference] = []
        var imageDataMap: [String: Data] = [:]
        var imageIndex = 0

        // Enumerate attachments in reverse to maintain correct positions
        var attachmentRanges: [(NSRange, NSTextAttachment)] = []
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachmentRanges.append((range, attachment))
            }
        }

        // Process in reverse order to maintain character positions
        for (range, attachment) in attachmentRanges.reversed() {
            imageIndex += 1
            let imageId = String(format: "image_%03d", imageIndex)
            let filename = "\(imageId).png"

            // Get image data and convert to PNG
            var pngData: Data?
            var imageSize: CGSize = .zero

            if let image = attachment.image {
                pngData = convertToPNG(image: image)
                imageSize = image.size
            } else if let wrapper = attachment.fileWrapper,
                      let data = wrapper.regularFileContents {
                if let image = NSImage(data: data) {
                    pngData = convertToPNG(image: image)
                    imageSize = image.size
                }
            }

            // Use attachment bounds if set
            if attachment.bounds.width > 0 && attachment.bounds.height > 0 {
                imageSize = attachment.bounds.size
            }

            if let data = pngData {
                imageDataMap[filename] = data

                let ref = ImageReference(
                    id: imageId,
                    filename: filename,
                    width: imageSize.width,
                    height: imageSize.height,
                    originalPosition: range.location
                )
                imageRefs.insert(ref, at: 0)  // Insert at beginning since we're processing in reverse

                // Replace attachment with placeholder text
                let placeholder = "[\(imageId)]"
                mutable.replaceCharacters(in: range, with: placeholder)
            }
        }

        return (mutable, imageRefs, imageDataMap)
    }

    /// Convert NSImage to PNG data
    private static func convertToPNG(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - Image Re-embedding

    /// Re-embed images into attributed string from image references
    private static func reembedImages(
        into attributed: NSAttributedString,
        imageRefs: [ImageReference],
        imagesFolder: URL
    ) throws -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)

        // Sort by original position (descending) to process from end to beginning
        let sortedRefs = imageRefs.sorted { $0.originalPosition > $1.originalPosition }

        for ref in sortedRefs {
            let placeholder = "[\(ref.id)]"
            let searchRange = NSRange(location: 0, length: mutable.length)
            let range = (mutable.string as NSString).range(of: placeholder, options: [], range: searchRange)

            guard range.location != NSNotFound else { continue }

            let imageURL = imagesFolder.appendingPathComponent(ref.filename)

            if let imageData = try? Data(contentsOf: imageURL),
               let image = NSImage(data: imageData) {

                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: 0, width: ref.width, height: ref.height)

                let imageString = NSAttributedString(attachment: attachment)
                mutable.replaceCharacters(in: range, with: imageString)
            }
        }

        return mutable
    }

    // MARK: - Legacy ZIP Support

    private static func listFilesInLegacyZip(data: Data) throws -> [String] {
        guard let eocdOffset = findEOCD(in: data) else {
            throw QuillDocumentError.invalidFormat
        }

        let cdOffset = Int(data.readUInt32LE(at: eocdOffset + 16))
        let totalEntries = Int(data.readUInt16LE(at: eocdOffset + 10))

        var filenames: [String] = []
        var cursor = cdOffset
        for _ in 0..<totalEntries {
            let filenameLength = Int(data.readUInt16LE(at: cursor + 28))
            let extraLen = Int(data.readUInt16LE(at: cursor + 30))
            let commentLen = Int(data.readUInt16LE(at: cursor + 32))

            let filenameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + filenameLength))
            let filename = String(decoding: filenameData, as: UTF8.self)
            filenames.append(filename)

            cursor += 46 + filenameLength + extraLen + commentLen
        }

        return filenames
    }

    private static func extractFromLegacyZip(data: Data, filename: String) throws -> Data {
        guard let eocdOffset = findEOCD(in: data) else {
            throw QuillDocumentError.invalidFormat
        }

        let cdOffset = Int(data.readUInt32LE(at: eocdOffset + 16))
        let totalEntries = Int(data.readUInt16LE(at: eocdOffset + 10))

        var cursor = cdOffset
        for _ in 0..<totalEntries {
            let filenameLength = Int(data.readUInt16LE(at: cursor + 28))
            let extraLen = Int(data.readUInt16LE(at: cursor + 30))
            let commentLen = Int(data.readUInt16LE(at: cursor + 32))
            let localHeaderOffset = Int(data.readUInt32LE(at: cursor + 42))

            let filenameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + filenameLength))
            let foundFilename = String(decoding: filenameData, as: UTF8.self)

            if foundFilename == filename {
                let localFilenameLength = Int(data.readUInt16LE(at: localHeaderOffset + 26))
                let localExtraLen = Int(data.readUInt16LE(at: localHeaderOffset + 28))
                let compressedSize = Int(data.readUInt32LE(at: localHeaderOffset + 18))
                let dataStart = localHeaderOffset + 30 + localFilenameLength + localExtraLen
                return data.subdata(in: dataStart..<(dataStart + compressedSize))
            }

            cursor += 46 + filenameLength + extraLen + commentLen
        }

        throw QuillDocumentError.fileNotFound(filename)
    }

    private static func findEOCD(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let start = max(0, data.count - 65536)
        var i = data.count - 22
        while i >= start {
            if data.readUInt32LE(at: i) == 0x06054b50 {
                return i
            }
            i -= 1
        }
        return nil
    }
}

// MARK: - Errors

enum QuillDocumentError: LocalizedError {
    case missingDocumentJson
    case missingTextRtf
    case invalidFormat
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingDocumentJson:
            return "Missing document.json in package"
        case .missingTextRtf:
            return "Missing text.rtf in package"
        case .invalidFormat:
            return "Invalid document format"
        case .fileNotFound(let name):
            return "File '\(name)' not found in package"
        }
    }
}

// MARK: - Legacy Metadata (for ZIP format compatibility)

private struct LegacyMetadataFile: Codable {
    let metadata: QuillDocument.Metadata
    let styles: [String: StyleDefinition]
}

// MARK: - Data Extensions

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        let b0 = UInt16(self[offset])
        let b1 = UInt16(self[offset + 1])
        return b0 | (b1 << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}
