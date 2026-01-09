import Cocoa

/// Best-effort importer for plain-text screenplay files (including Fade In `.fadein`).
///
/// Produces an attributed string using the current StyleCatalog template.
/// Callers should switch `StyleCatalog.shared.currentTemplateName` to `"Screenplay"`
/// before invoking so the expected screenplay styles exist.
struct ScreenplayImporter {

    private static let styleAttributeKey = NSAttributedString.Key("QuillStyleName")

    enum Element {
        case title
        case author
        case contact
        case draft
        case slugline
        case action
        case character
        case parenthetical
        case dialogue
        case transition
        case shot
    }

    static func attributedString(fromPlainText input: String) -> NSAttributedString {
        // Normalize newlines.
        let normalized = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        let result = NSMutableAttributedString()

        var inTitlePage = true
        var sawBodySlugline = false
        var sawTitleLine = false
        var sawAuthorLine = false
        var expectingDialogue = false

        func appendLine(_ text: String, styleName: String) {
            let attributes = attributesForStyle(named: styleName)
            let line = NSAttributedString(string: text, attributes: attributes)
            result.append(line)
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        for rawLine in lines {
            // Strip leading/trailing whitespace; indentation is handled by paragraph styles.
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let trimmedUpper = trimmed.uppercased()

            if trimmed.isEmpty {
                // Blank line terminates dialogue blocks.
                expectingDialogue = false
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            if inTitlePage {
                if isSlugline(trimmedUpper) {
                    inTitlePage = false
                    sawBodySlugline = true
                } else {
                    let element = classifyTitlePageLine(trimmed)
                    switch element {
                    case .contact:
                        appendLine(trimmed, styleName: "Screenplay — Contact")
                    case .draft:
                        appendLine(trimmed, styleName: "Screenplay — Draft")
                    default:
                        if !sawTitleLine {
                            sawTitleLine = true
                            appendLine(trimmed, styleName: "Screenplay — Title")
                        } else if !sawAuthorLine {
                            sawAuthorLine = true
                            appendLine(trimmed, styleName: "Screenplay — Author")
                        } else {
                            appendLine(trimmed, styleName: "Screenplay — Author")
                        }
                    }
                    continue
                }
            }

            // Body classification.
            let element: Element
            if isSlugline(trimmedUpper) {
                element = .slugline
                expectingDialogue = false
            } else if isTransition(trimmedUpper) {
                element = .transition
                expectingDialogue = false
            } else if isShot(trimmedUpper) {
                element = .shot
                expectingDialogue = false
            } else if isCharacter(trimmed, uppercased: trimmedUpper) {
                element = .character
                expectingDialogue = true
            } else if expectingDialogue && isParenthetical(trimmed) {
                element = .parenthetical
                expectingDialogue = true
            } else if expectingDialogue {
                element = .dialogue
            } else {
                element = .action
            }

            sawBodySlugline = sawBodySlugline || (element == .slugline)

            switch element {
            case .slugline:
                appendLine(trimmed, styleName: "Screenplay — Slugline")
            case .action:
                appendLine(trimmed, styleName: "Screenplay — Action")
            case .character:
                appendLine(trimmed, styleName: "Screenplay — Character")
            case .parenthetical:
                appendLine(trimmed, styleName: "Screenplay — Parenthetical")
            case .dialogue:
                appendLine(trimmed, styleName: "Screenplay — Dialogue")
            case .transition:
                appendLine(trimmed, styleName: "Screenplay — Transition")
            case .shot:
                appendLine(trimmed, styleName: "Screenplay — Shot")
            case .title, .author, .contact, .draft:
                // Title page already handled.
                appendLine(trimmed, styleName: "Screenplay — Action")
            }
        }

        // If the file had a title page but no body, still return something styled.
        if !sawBodySlugline && sawTitleLine {
            // No-op; already added title page lines.
        }

        return result
    }

    static func looksLikeScreenplay(_ input: String) -> Bool {
        // Conservative heuristic: screenplay sluglines are very distinctive.
        let normalized = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true).prefix(200)
        for lineSub in lines {
            let line = String(lineSub).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if isSlugline(line.uppercased()) { return true }
        }
        return false
    }

    // MARK: - Classification

    private static func classifyTitlePageLine(_ trimmed: String) -> Element {
        let lower = trimmed.lowercased()
        if lower.contains("contact") || lower.contains("@") || lower.contains("tel") || lower.contains("phone") {
            return .contact
        }
        if lower.contains("draft") || lower.contains("copyright") || lower.contains("(c)") {
            return .draft
        }
        // Default: title/author-ish, caller decides sequence.
        return .title
    }

    private static func isParenthetical(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("(") && trimmed.contains(")")
    }

    private static func isSlugline(_ upper: String) -> Bool {
        // Common slugline prefixes.
        let prefixes = ["INT.", "EXT.", "INT/EXT.", "EXT/INT.", "I/E.", "EST."]
        return prefixes.first(where: { upper.hasPrefix($0) }) != nil
    }

    private static func isTransition(_ upper: String) -> Bool {
        if upper.hasSuffix("TO:") { return true }
        let known = [
            "CUT TO:",
            "SMASH CUT TO:",
            "DISSOLVE TO:",
            "MATCH CUT TO:",
            "FADE IN:",
            "FADE OUT.",
            "FADE OUT:",
            "FADE TO BLACK.",
            "FADE TO BLACK:",
            "WIPE TO:",
            "JUMP CUT TO:"
        ]
        if known.contains(upper) { return true }
        // Transition lines are often all-caps and end with ':'
        if upper.count <= 30 && upper.hasSuffix(":") { return true }
        return false
    }

    private static func isShot(_ upper: String) -> Bool {
        let prefixes = [
            "ANGLE ON", "CLOSE ON", "CLOSE-UP", "CU ", "WIDE SHOT", "ESTABLISHING", "INSERT", "CUTAWAY",
            "POV", "TRACKING", "DOLLY", "PAN", "TILT", "OVER", "ON "
        ]
        return prefixes.first(where: { upper.hasPrefix($0) }) != nil
    }

    private static func isCharacter(_ trimmed: String, uppercased upper: String) -> Bool {
        // Avoid classifying sluglines/transitions as characters.
        if isSlugline(upper) || isTransition(upper) || isShot(upper) { return false }

        // Character cues are typically short and mostly uppercase.
        let plain = trimmed.trimmingCharacters(in: .whitespaces)
        guard !plain.isEmpty else { return false }
        guard plain.count <= 35 else { return false }

        // Allow punctuation commonly used in character cues.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .'-()")
        let scalars = plain.unicodeScalars
        guard scalars.allSatisfy({ allowed.contains($0) }) else { return false }

        // Must contain at least one A-Z.
        guard scalars.contains(where: { CharacterSet.uppercaseLetters.contains($0) }) else { return false }

        // Heuristic: treat as character if it equals its uppercased form.
        return plain == upper
    }

    // MARK: - Styling

    private static func attributesForStyle(named styleName: String) -> [NSAttributedString.Key: Any] {
        let theme = ThemeManager.shared.currentTheme

        guard let definition = StyleCatalog.shared.style(named: styleName) else {
            // Fallback: plain text with theme color.
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
        var font = NSFont.quillPilotResolve(nameOrFamily: definition.fontName, size: definition.fontSize)
            ?? NSFont.systemFont(ofSize: definition.fontSize)
        if definition.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if definition.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }
}
