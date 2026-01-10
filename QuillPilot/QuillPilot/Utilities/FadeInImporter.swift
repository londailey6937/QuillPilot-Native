import Cocoa
import Foundation
import zlib

/// Imports Fade In `.fadein` files, which are ZIP archives containing an Open Screenplay Format `document.xml`.
///
/// We extract `document.xml` via `/usr/bin/unzip` (handles deflate) and parse paragraph styles to map
/// to QuillPilot's built-in Screenplay template styles.
struct FadeInImporter {
    private static let styleAttributeKey = NSAttributedString.Key("QuillStyleName")

    static func isZipArchive(at url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        let header = (try? fh.read(upToCount: 4)) ?? Data()
        return header.count >= 2 && header[0] == 0x50 && header[1] == 0x4B // 'P' 'K'
    }

    static func attributedString(fromFadeInURL url: URL) throws -> NSAttributedString {
        let zipData = try Data(contentsOf: url, options: [.mappedIfSafe])
        let xmlData = try ZipReader.extractXMLDocument(from: zipData)

        let parser = OSFParser()
        try parser.parse(xmlData: xmlData)

        let result = NSMutableAttributedString()
        for paragraph in parser.paragraphs {
            let styleName = mapToQuillStyle(baseStyle: paragraph.baseStyle, align: paragraph.align)
            let baseAttributes = attributesForStyle(named: styleName)

            // Fade In stores style intent separately from text casing. For common screenplay elements,
            // normalize to all-caps so QuillPilot's screenplay styles match expectations.
            var runs = paragraph.runs
            if styleName == "Screenplay — Slugline" ||
                styleName == "Screenplay — Character" ||
                styleName == "Screenplay — Transition" ||
                styleName == "Screenplay — Shot" {
                runs = runs.map {
                    var r = $0
                    r.text = r.text.uppercased()
                    return r
                }
            }
            if styleName == "Screenplay — Slugline" {
                runs = runs.map {
                    var r = $0
                    r.text = r.text.replacingOccurrences(of: " - ", with: " – ")
                    return r
                }
            }

            let paragraphText = runs.map { $0.text }.joined()
            let paraAttributed = NSMutableAttributedString(string: paragraphText, attributes: baseAttributes)

            // Apply run-level formatting when present.
            var cursor = 0
            for run in runs {
                let length = (run.text as NSString).length
                let range = NSRange(location: cursor, length: length)
                cursor += length

                var runFont = (baseAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 12)
                if run.bold { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask) }
                if run.italic { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask) }

                var attrs: [NSAttributedString.Key: Any] = [.font: runFont]
                if run.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }

                // Fade In title pages sometimes include explicit sizes; apply only for Title lines.
                if styleName == "Screenplay — Title", let size = run.size, size > 0 {
                    let sized = NSFontManager.shared.convert(runFont, toSize: size)
                    attrs[.font] = sized
                }

                if range.location + range.length <= paraAttributed.length {
                    paraAttributed.addAttributes(attrs, range: range)
                }
            }

            result.append(paraAttributed)
            result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        }

        return result
    }

    // MARK: - ZIP extraction (no external processes)

    private enum ZipReader {
        // Signatures
        private static let sigEOCD: UInt32 = 0x06054b50
        private static let sigCD: UInt32 = 0x02014b50
        private static let sigLFH: UInt32 = 0x04034b50

        private struct CentralEntry {
            let name: String
            let method: UInt16
            let compressedSize: UInt32
            let uncompressedSize: UInt32
            let localHeaderOffset: UInt32
        }

        static func extractXMLDocument(from zipData: Data) throws -> Data {
            guard zipData.count >= 4 else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid .fadein file."])
            }

            let entries = try readCentralDirectory(zipData)

            // Prefer exact document.xml; else any */document.xml; else any .xml.
            let chosen: CentralEntry?
            if let exact = entries.first(where: { $0.name.lowercased() == "document.xml" }) {
                chosen = exact
            } else if let nested = entries.first(where: { $0.name.lowercased().hasSuffix("/document.xml") }) {
                chosen = nested
            } else {
                chosen = entries.first(where: { $0.name.lowercased().hasSuffix(".xml") })
            }

            guard let entry = chosen else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 11, userInfo: [NSLocalizedDescriptionKey: "Fade In archive did not contain document.xml."])
            }

            return try extractEntry(zipData, entry: entry)
        }

        private static func readCentralDirectory(_ data: Data) throws -> [CentralEntry] {
            // EOCD is within the last 65,557 bytes (max comment length 65535 + 22).
            let maxTail = min(data.count, 65557)
            let start = data.count - maxTail
            let tail = data.subdata(in: start..<data.count)

            guard let eocdOffsetInTail = lastIndexOfSignature(sigEOCD, in: tail) else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 12, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP (missing end record)."])
            }
            let eocdOffset = start + eocdOffsetInTail

            // EOCD structure (fixed 22 bytes before comment):
            // 0: sig (4)
            // 10: total entries (2)
            // 12: central dir size (4)
            // 16: central dir offset (4)
            let totalEntries = readUInt16LE(data, at: eocdOffset + 10)
            let cdSize = Int(readUInt32LE(data, at: eocdOffset + 12))
            let cdOffset = Int(readUInt32LE(data, at: eocdOffset + 16))

            guard cdOffset >= 0, cdSize >= 0, cdOffset + cdSize <= data.count else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 13, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP (central directory out of bounds)."])
            }

            var entries: [CentralEntry] = []
            entries.reserveCapacity(Int(totalEntries))

            var cursor = cdOffset
            let end = cdOffset + cdSize

            while cursor + 46 <= end {
                let sig = readUInt32LE(data, at: cursor)
                guard sig == sigCD else { break }

                let method = readUInt16LE(data, at: cursor + 10)
                let compressedSize = readUInt32LE(data, at: cursor + 20)
                let uncompressedSize = readUInt32LE(data, at: cursor + 24)
                let fileNameLen = Int(readUInt16LE(data, at: cursor + 28))
                let extraLen = Int(readUInt16LE(data, at: cursor + 30))
                let commentLen = Int(readUInt16LE(data, at: cursor + 32))
                let localHeaderOffset = readUInt32LE(data, at: cursor + 42)

                let nameStart = cursor + 46
                let nameEnd = nameStart + fileNameLen
                guard nameEnd <= end else { break }

                let nameData = data.subdata(in: nameStart..<nameEnd)
                let name = String(data: nameData, encoding: .utf8) ?? String(decoding: nameData, as: UTF8.self)

                entries.append(CentralEntry(
                    name: name,
                    method: method,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                ))

                cursor = nameEnd + extraLen + commentLen
            }

            return entries
        }

        private static func extractEntry(_ data: Data, entry: CentralEntry) throws -> Data {
            let lfhOffset = Int(entry.localHeaderOffset)
            guard lfhOffset + 30 <= data.count else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 14, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP (local header out of bounds)."])
            }

            let sig = readUInt32LE(data, at: lfhOffset)
            guard sig == sigLFH else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 15, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP (bad local header signature)."])
            }

            let fileNameLen = Int(readUInt16LE(data, at: lfhOffset + 26))
            let extraLen = Int(readUInt16LE(data, at: lfhOffset + 28))

            let dataStart = lfhOffset + 30 + fileNameLen + extraLen
            let compSize = Int(entry.compressedSize)
            let dataEnd = dataStart + compSize
            guard dataStart >= 0, dataEnd <= data.count else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 16, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP (entry data out of bounds)."])
            }

            let compressed = data.subdata(in: dataStart..<dataEnd)

            switch entry.method {
            case 0:
                return compressed
            case 8:
                return try inflateRawDeflate(compressed, expectedSize: Int(entry.uncompressedSize))
            default:
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 17, userInfo: [NSLocalizedDescriptionKey: "Unsupported ZIP compression method: \(entry.method)"])
            }
        }

        private static func inflateRawDeflate(_ compressed: Data, expectedSize: Int) throws -> Data {
            var stream = z_stream()
            stream.zalloc = nil
            stream.zfree = nil
            stream.opaque = nil

            let initResult = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            guard initResult == Z_OK else {
                throw NSError(domain: "QuillPilot.FadeInImporter", code: 18, userInfo: [NSLocalizedDescriptionKey: "Failed to init zlib inflater."])
            }
            defer {
                inflateEnd(&stream)
            }

            // If expectedSize is 0 (unknown), start with a reasonable chunk.
            var output = Data(count: max(expectedSize, 64 * 1024))
            var totalOut: Int = 0

            try compressed.withUnsafeBytes { (inBytesRaw: UnsafeRawBufferPointer) in
                guard let inBase = inBytesRaw.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                stream.next_in = UnsafeMutablePointer<UInt8>(mutating: inBase)
                stream.avail_in = uInt(compressed.count)

                var status: Int32 = Z_OK

                while status != Z_STREAM_END {
                    if totalOut >= output.count {
                        output.count *= 2
                    }

                    let outSpace = output.count - totalOut
                    let producedThisPass: Int = try output.withUnsafeMutableBytes { (outBytesRaw: UnsafeMutableRawBufferPointer) in
                        guard let outBase = outBytesRaw.bindMemory(to: UInt8.self).baseAddress else {
                            throw NSError(domain: "QuillPilot.FadeInImporter", code: 19, userInfo: [NSLocalizedDescriptionKey: "Failed to access output buffer."])
                        }

                        stream.next_out = outBase.advanced(by: totalOut)
                        stream.avail_out = uInt(outSpace)

                        status = inflate(&stream, Z_FINISH)

                        if status != Z_OK && status != Z_STREAM_END && status != Z_BUF_ERROR {
                            let msg = stream.msg.map { String(cString: $0) } ?? "Unknown zlib error"
                            throw NSError(domain: "QuillPilot.FadeInImporter", code: 20, userInfo: [NSLocalizedDescriptionKey: "Decompression failed: \(msg)"])
                        }

                        let remaining = Int(stream.avail_out)
                        return outSpace - remaining
                    }

                    totalOut += producedThisPass

                    // If we hit buffer error due to needing more output space, loop again.
                    if status == Z_BUF_ERROR {
                        // Continue; output will grow next iteration.
                        status = Z_OK
                    }
                }
            }

            output.count = totalOut
            return output
        }

        private static func lastIndexOfSignature(_ sig: UInt32, in data: Data) -> Int? {
            if data.count < 4 { return nil }
            let sigBytes: [UInt8] = [
                UInt8(sig & 0xFF),
                UInt8((sig >> 8) & 0xFF),
                UInt8((sig >> 16) & 0xFF),
                UInt8((sig >> 24) & 0xFF)
            ]

            var i = data.count - 4
            while i >= 0 {
                if data[i] == sigBytes[0] && data[i + 1] == sigBytes[1] && data[i + 2] == sigBytes[2] && data[i + 3] == sigBytes[3] {
                    return i
                }
                i -= 1
            }
            return nil
        }

        private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
            let b0 = UInt16(data[offset])
            let b1 = UInt16(data[offset + 1])
            return b0 | (b1 << 8)
        }

        private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
            let b0 = UInt32(data[offset])
            let b1 = UInt32(data[offset + 1])
            let b2 = UInt32(data[offset + 2])
            let b3 = UInt32(data[offset + 3])
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }
    }

    // MARK: - OSF parsing

    private struct OSFParagraph {
        var baseStyle: String?
        var align: String?
        var runs: [OSFRun]
    }

    private struct OSFRun {
        var text: String
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var size: CGFloat?
    }

    private final class OSFParser: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [OSFParagraph] = []

        private var currentParagraph: OSFParagraph?
        private var currentRun: OSFRun?
        private var inPara = false

        func parse(xmlData: Data) throws {
            let parser = XMLParser(data: xmlData)
            parser.delegate = self
            parser.shouldResolveExternalEntities = false
            if !parser.parse() {
                throw parser.parserError ?? NSError(
                    domain: "QuillPilot.FadeInImporter",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse Fade In document.xml"]
                )
            }
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "para":
                inPara = true
                currentParagraph = OSFParagraph(baseStyle: nil, align: nil, runs: [])
            case "style":
                guard inPara else { return }
                if let base = attributeDict["basestyle"] {
                    currentParagraph?.baseStyle = base
                }
                if let align = attributeDict["align"] {
                    currentParagraph?.align = align
                }
            case "text":
                guard inPara else { return }
                let bold = attributeDict["bold"] == "1"
                let italic = attributeDict["italic"] == "1"
                let underline = attributeDict["underline"] == "1" || attributeDict["under"] == "1"

                var size: CGFloat?
                if let sizeStr = attributeDict["size"], let dbl = Double(sizeStr) {
                    size = CGFloat(dbl)
                }

                currentRun = OSFRun(text: "", bold: bold, italic: italic, underline: underline, size: size)
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard inPara else { return }
            if currentRun != nil {
                currentRun?.text += string
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "text":
                if let run = currentRun {
                    currentParagraph?.runs.append(run)
                }
                currentRun = nil
            case "para":
                inPara = false
                if let p = currentParagraph {
                    // If a paragraph had no explicit <text>, still preserve an empty line.
                    paragraphs.append(p.runs.isEmpty ? OSFParagraph(baseStyle: p.baseStyle, align: p.align, runs: [OSFRun(text: "", bold: false, italic: false, underline: false, size: nil)]) : p)
                }
                currentParagraph = nil
            default:
                break
            }
        }
    }

    // MARK: - Style mapping

    private static func mapToQuillStyle(baseStyle: String?, align: String?) -> String {
        let base = (baseStyle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = base.lowercased()
        let alignLower = (align ?? "").lowercased()

        // Title page in Fade In often uses "Normal Text" with center alignment and larger sizes.
        if alignLower == "center" {
            return "Screenplay — Title"
        }

        switch lower {
        case "scene heading":
            return "Screenplay — Slugline"
        case "action":
            return "Screenplay — Action"
        case "character":
            return "Screenplay — Character"
        case "parenthetical":
            return "Screenplay — Parenthetical"
        case "dialogue":
            return "Screenplay — Dialogue"
        case "transition":
            return "Screenplay — Transition"
        case "shot":
            return "Screenplay — Shot"
        case "normal text":
            return "Screenplay — Action"
        default:
            // Right-aligned lines are typically transitions.
            if alignLower == "right" {
                return "Screenplay — Transition"
            }
            return "Screenplay — Action"
        }
    }

    private static func attributesForStyle(named styleName: String) -> [NSAttributedString.Key: Any] {
        let theme = ThemeManager.shared.currentTheme

        guard let definition = StyleCatalog.shared.style(named: styleName) else {
            return [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: theme.textColor,
                styleAttributeKey: styleName
            ]
        }

        let paragraph = paragraphStyle(from: definition)
        let font = font(from: definition)

        return [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: theme.textColor,
            styleAttributeKey: styleName
        ]
    }

    private static func paragraphStyle(from definition: StyleDefinition) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment(rawValue: definition.alignmentRawValue) ?? .left
        style.lineHeightMultiple = definition.lineHeightMultiple
        style.paragraphSpacingBefore = definition.spacingBefore
        style.paragraphSpacing = definition.spacingAfter
        style.headIndent = definition.headIndent
        style.firstLineHeadIndent = definition.firstLineIndent
        style.tailIndent = definition.tailIndent
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }

    private static func font(from definition: StyleDefinition) -> NSFont {
        let base = NSFont.quillPilotResolve(nameOrFamily: definition.fontName, size: definition.fontSize)
            ?? NSFont.systemFont(ofSize: definition.fontSize)

        var font = base
        if definition.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if definition.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }
}
