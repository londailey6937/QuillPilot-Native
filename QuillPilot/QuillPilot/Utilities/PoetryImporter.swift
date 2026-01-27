import Cocoa

/// Conservative importer for plain-text poetry.
///
/// Goals:
/// - Preserve hard line breaks (each line becomes its own paragraph)
/// - Preserve leading indentation (shaped poems)
/// - Apply a Poetry template style tag per line so later retagging doesn't collapse formatting
///
/// Callers should switch StyleCatalog.shared.currentTemplateName to "Poetry" before invoking.
struct PoetryImporter {
    private static let styleAttributeKey = NSAttributedString.Key("QuillStyleName")

    static func looksLikePoetry(_ input: String) -> Bool {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).prefix(250)
        let lines = rawLines.map(String.init)

        var nonEmptyCount = 0
        var blankCount = 0
        var indentedCount = 0
        var shortCount = 0
        var punctuationEndCount = 0
        var totalLen = 0

        let punctuationEnd = CharacterSet(charactersIn: ".,;:!?\"'”)”»")

        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankCount += 1
                continue
            }

            nonEmptyCount += 1

            if line.first == " " || line.first == "\t" {
                indentedCount += 1
            }

            let visible = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let len = (visible as NSString).length
            totalLen += len
            if len <= 45 { shortCount += 1 }

            if let last = visible.unicodeScalars.last, punctuationEnd.contains(last) {
                punctuationEndCount += 1
            }
        }

        guard nonEmptyCount >= 8 else { return false }

        let avgLen = Double(totalLen) / Double(max(nonEmptyCount, 1))
        let shortFrac = Double(shortCount) / Double(nonEmptyCount)
        let indentedFrac = Double(indentedCount) / Double(nonEmptyCount)
        let punctFrac = Double(punctuationEndCount) / Double(nonEmptyCount)

        // Conservative: prefer many short lines, some stanza breaks, and avoid fully punctuated prose.
        if blankCount >= 2 && shortFrac >= 0.55 && avgLen <= 60 && punctFrac <= 0.75 {
            return true
        }

        if indentedFrac >= 0.20 && shortFrac >= 0.50 && avgLen <= 65 {
            return true
        }

        if nonEmptyCount >= 20 && avgLen <= 38 {
            return true
        }

        return false
    }

    static func attributedString(fromPlainText input: String) -> NSAttributedString {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = NSMutableAttributedString()

        // Detect a simple title/author header: a few non-empty lines before the first blank line.
        var headerLines: [String] = []
        headerLines.reserveCapacity(3)
        var headerEndIndex: Int?

        for (idx, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !headerLines.isEmpty {
                    headerEndIndex = idx
                }
                break
            }
            if headerLines.count < 3 {
                headerLines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                break
            }
        }

        func isReasonableHeader(_ l: [String]) -> Bool {
            guard !l.isEmpty else { return false }
            if (l[0] as NSString).length > 80 { return false }
            return true
        }

        let hasHeader = (headerEndIndex != nil) && isReasonableHeader(headerLines)

        func appendLine(_ text: String, styleName: String) {
            let attributes = attributesForStyle(named: styleName)
            let trimmedRight = text.replacingOccurrences(of: "[ \t]+$", with: "", options: .regularExpression)
            result.append(NSAttributedString(string: trimmedRight, attributes: attributes))
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        func appendStanzaBreak() {
            let attributes = attributesForStyle(named: "Poetry — Stanza Break")
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        var startIdx = 0
        if hasHeader, let end = headerEndIndex {
            if !headerLines.isEmpty {
                appendLine(headerLines[0], styleName: "Poetry — Title")
            }
            if headerLines.count >= 2 {
                appendLine(headerLines[1], styleName: "Poetry — Author")
            }
            if headerLines.count >= 3 {
                appendLine(headerLines[2], styleName: "Poetry — Author")
            }
            appendStanzaBreak()
            startIdx = end + 1
        }

        for i in startIdx..<lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendStanzaBreak()
                continue
            }
            appendLine(line, styleName: "Stanza")
        }

        return result
    }

    // MARK: - Styling

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
        style.firstLineHeadIndent = definition.headIndent + definition.firstLineIndent
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
