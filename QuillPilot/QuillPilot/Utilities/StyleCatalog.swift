import Cocoa

extension Notification.Name {
    static let styleTemplateDidChange = Notification.Name("styleTemplateDidChange")
}

extension NSFont {
    /// Resolves either a PostScript font name (e.g. "TimesNewRomanPSMT") or a font family name
    /// (e.g. "Times New Roman", "Inter") into a concrete font at the given size.
    ///
    /// Many UI pickers use family names, while `NSFont(name:size:)` expects a PostScript name.
    static func quillPilotResolve(nameOrFamily: String, size: CGFloat) -> NSFont? {
        if let exact = NSFont(name: nameOrFamily, size: size) {
            return exact
        }

        let familyDescriptor = NSFontDescriptor(fontAttributes: [.family: nameOrFamily])
        if let byFamily = NSFont(descriptor: familyDescriptor, size: size) {
            return byFamily
        }

        // As a last resort, ask NSFontManager to convert a base font.
        // If the family doesn't exist, this generally returns the input font unchanged.
        let base = NSFont.systemFont(ofSize: size)
        return NSFontManager.shared.convert(base, toFamily: nameOrFamily)
    }
}

struct StyleDefinition: Codable {
    var fontName: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var useSmallCaps: Bool
    var textColorHex: String
    var backgroundColorHex: String?
    var alignmentRawValue: Int
    var lineHeightMultiple: CGFloat
    var spacingBefore: CGFloat
    var spacingAfter: CGFloat
    var headIndent: CGFloat
    var firstLineIndent: CGFloat
    var tailIndent: CGFloat

    init(
        fontName: String,
        fontSize: CGFloat,
        isBold: Bool,
        isItalic: Bool,
        useSmallCaps: Bool = false,
        textColorHex: String,
        backgroundColorHex: String? = nil,
        alignmentRawValue: Int,
        lineHeightMultiple: CGFloat,
        spacingBefore: CGFloat,
        spacingAfter: CGFloat,
        headIndent: CGFloat,
        firstLineIndent: CGFloat,
        tailIndent: CGFloat
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.useSmallCaps = useSmallCaps
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.alignmentRawValue = alignmentRawValue
        self.lineHeightMultiple = lineHeightMultiple
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.headIndent = headIndent
        self.firstLineIndent = firstLineIndent
        self.tailIndent = tailIndent
    }

    private enum CodingKeys: String, CodingKey {
        case fontName
        case fontSize
        case isBold
        case isItalic
        case useSmallCaps
        case textColorHex
        case backgroundColorHex
        case alignmentRawValue
        case lineHeightMultiple
        case spacingBefore
        case spacingAfter
        case headIndent
        case firstLineIndent
        case tailIndent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        isBold = try container.decode(Bool.self, forKey: .isBold)
        isItalic = try container.decode(Bool.self, forKey: .isItalic)
        useSmallCaps = try container.decodeIfPresent(Bool.self, forKey: .useSmallCaps) ?? false
        textColorHex = try container.decode(String.self, forKey: .textColorHex)
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
        alignmentRawValue = try container.decode(Int.self, forKey: .alignmentRawValue)
        lineHeightMultiple = try container.decode(CGFloat.self, forKey: .lineHeightMultiple)
        spacingBefore = try container.decode(CGFloat.self, forKey: .spacingBefore)
        spacingAfter = try container.decode(CGFloat.self, forKey: .spacingAfter)
        headIndent = try container.decode(CGFloat.self, forKey: .headIndent)
        firstLineIndent = try container.decode(CGFloat.self, forKey: .firstLineIndent)
        tailIndent = try container.decode(CGFloat.self, forKey: .tailIndent)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encode(useSmallCaps, forKey: .useSmallCaps)
        try container.encode(textColorHex, forKey: .textColorHex)
        try container.encodeIfPresent(backgroundColorHex, forKey: .backgroundColorHex)
        try container.encode(alignmentRawValue, forKey: .alignmentRawValue)
        try container.encode(lineHeightMultiple, forKey: .lineHeightMultiple)
        try container.encode(spacingBefore, forKey: .spacingBefore)
        try container.encode(spacingAfter, forKey: .spacingAfter)
        try container.encode(headIndent, forKey: .headIndent)
        try container.encode(firstLineIndent, forKey: .firstLineIndent)
        try container.encode(tailIndent, forKey: .tailIndent)
    }
}

struct StyleTemplate: Codable {
    let name: String
    let styles: [String: StyleDefinition]
}

final class StyleCatalog {
    static let shared = StyleCatalog()

    private(set) var currentTemplateName: String
    private var templates: [String: StyleTemplate]
    private let defaults = UserDefaults.standard
    private let templateKey = "StyleCatalog.CurrentTemplate"
    private let overridesPrefix = "StyleCatalog.Overrides."

    private init() {
        let builtIns = StyleCatalog.buildTemplates()
        self.templates = Dictionary(uniqueKeysWithValues: builtIns.map { ($0.name, $0) })
        let savedTemplate = defaults.string(forKey: templateKey)
        if let saved = savedTemplate, templates[saved] != nil {
            currentTemplateName = saved
        } else {
            currentTemplateName = "Palatino"
        }
    }

    func availableTemplates() -> [String] {
        templates.keys.sorted()
    }

    func styleNames(for templateName: String) -> [String] {
        let keys = templates[templateName]?.styles.keys.map { $0 } ?? []
        // Poetry: prefer modern naming in UI while keeping legacy keys for existing docs.
        if templateName.lowercased().contains("poetry") {
            return keys
                .filter { key in
                    // Keep legacy keys available for opening old docs, but hide them from UI pickers.
                    if key == "Poetry — Verse" { return false }
                    if key == "Poetry — Stanza" { return false }
                    // Structural/container styles: keep for internal tagging/back-compat, but don't show in dropdown.
                    if key == "Poem" { return false }
                    // In Poetry templates, Verse is the writer-facing text style; hide generic Body Text variants.
                    if key == "Body Text" { return false }
                    if key == "Body Text – No Indent" { return false }
                    return true
                }
                .sorted()
        }
        return keys.sorted()
    }

    /// Returns all style keys for a template, including styles hidden from UI pickers.
    ///
    /// This is primarily used for exporters (e.g., DOCX) so documents containing legacy or
    /// internal styles can round-trip without losing their paragraph style identity.
    func allStyleKeys(for templateName: String) -> [String] {
        let keys = templates[templateName]?.styles.keys.map { $0 } ?? []
        return keys.sorted()
    }

    func setCurrentTemplate(_ name: String) {
        guard templates[name] != nil else { return }
        guard currentTemplateName != name else { return }
        currentTemplateName = name
        defaults.set(name, forKey: templateKey)
        NotificationCenter.default.post(name: .styleTemplateDidChange, object: name)
    }

    var isScreenplayTemplate: Bool {
        currentTemplateName.lowercased().contains("screenplay")
    }

    var isPoetryTemplate: Bool {
        currentTemplateName.lowercased().contains("poetry")
    }

    func style(named name: String, inTemplate templateName: String) -> StyleDefinition? {
        let isPoetry = templateName.lowercased().contains("poetry")
        let candidateNames: [String]
        if isPoetry {
            switch name {
            case "Verse":
                candidateNames = ["Verse", "Body Text – No Indent", "Body Text"]
            case "Stanza", "Poem", "Body Text", "Body Text – No Indent", "Poetry — Verse", "Poetry — Stanza":
                candidateNames = ["Verse", "Body Text – No Indent", "Body Text", name]
            default:
                candidateNames = [name]
            }
        } else {
            candidateNames = [name]
        }

        let overrides = loadOverrides(for: templateName)
        for key in candidateNames {
            if let override = overrides[key] {
                return override
            }
        }
        for key in candidateNames {
            if let def = templates[templateName]?.styles[key] {
                return def
            }
        }
        return nil
    }

    func templateName(containingStyleName styleName: String) -> String? {
        for (name, template) in templates {
            if template.styles[styleName] != nil {
                return name
            }
        }
        return nil
    }

    func style(named name: String) -> StyleDefinition? {
        // Poetry model:
        // - Poem is structural (container) and should not define writer-facing appearance.
        // - Verse is the writer-facing typographic style.
        // For backwards compatibility, we resolve legacy/container names to Verse, while also honoring
        // any overrides a user may already have saved under older keys.
        let candidateNames: [String]
        if isPoetryTemplate {
            switch name {
            case "Verse":
                candidateNames = ["Verse", "Body Text – No Indent", "Body Text"]
            case "Stanza", "Poem", "Body Text", "Body Text – No Indent", "Poetry — Verse", "Poetry — Stanza":
                candidateNames = ["Verse", "Body Text – No Indent", "Body Text", name]
            default:
                candidateNames = [name]
            }
        } else {
            candidateNames = [name]
        }

        let overrides = loadOverrides(for: currentTemplateName)
        for key in candidateNames {
            if let override = overrides[key] {
                return override
            }
        }
        for key in candidateNames {
            if let def = templates[currentTemplateName]?.styles[key] {
                return def
            }
        }
        return nil
    }

    func saveOverride(_ definition: StyleDefinition, for styleName: String) {
        var overrides = loadOverrides(for: currentTemplateName)
        overrides[styleName] = definition
        persist(overrides: overrides, for: currentTemplateName)
    }

    func resetStyle(_ styleName: String) {
        var overrides = loadOverrides(for: currentTemplateName)
        overrides.removeValue(forKey: styleName)
        persist(overrides: overrides, for: currentTemplateName)
    }

    func resetAllOverrides() {
        persist(overrides: [:], for: currentTemplateName)
    }

    func resetAllOverridesAndNotify() {
        let template = currentTemplateName
        resetAllOverrides()
        NotificationCenter.default.post(name: .styleTemplateDidChange, object: template)
    }

    private func overridesKey(for template: String) -> String {
        overridesPrefix + template
    }

    private func loadOverrides(for template: String) -> [String: StyleDefinition] {
        let key = overridesKey(for: template)
        guard let data = defaults.data(forKey: key) else { return [:] }
        if let decoded = try? PropertyListDecoder().decode([String: StyleDefinition].self, from: data) {
            return decoded
        }
        return [:]
    }

    private func persist(overrides: [String: StyleDefinition], for template: String) {
        let key = overridesKey(for: template)
        if let data = try? PropertyListEncoder().encode(overrides) {
            defaults.set(data, forKey: key)
        }
    }

    private static func buildTemplates() -> [StyleTemplate] {
        func rebaseFonts(_ styles: [String: StyleDefinition], fontFamily: String) -> [String: StyleDefinition] {
            var rebased: [String: StyleDefinition] = [:]
            rebased.reserveCapacity(styles.count)
            for (key, def) in styles {
                var updated = def
                updated.fontName = fontFamily
                rebased[key] = updated
            }
            return rebased
        }

        func ensureStandardStyles(_ styles: [String: StyleDefinition], includePartStyles: Bool = true) -> [String: StyleDefinition] {
            var merged = styles

            let baseStyle: StyleDefinition? =
                merged["Body Text"] ??
                merged["Screenplay — Action"] ??
                merged.values.first

            guard let base = baseStyle else { return merged }

            let font = base.fontName
            let color = base.textColorHex
            let background = base.backgroundColorHex

            let baseSize = base.fontSize
            let h1Size = max(11, baseSize)
            let h2Size = max(11, baseSize - 1)
            let h3Size = max(10, baseSize - 2)
            let captionSize = max(10, baseSize - 3)

            if includePartStyles {
                // Ensure “Part …” structural styles exist across prose/manuscript templates.
                let partNumberSize = max(11, baseSize)
                let partTitleSize = max(16, baseSize + 6)
                let partSubtitleSize = max(11, baseSize)

                if merged["Part Number"] == nil {
                    merged["Part Number"] = baseDefinition(
                        font: font,
                        size: partNumberSize,
                        bold: true,
                        italic: false,
                        color: color,
                        background: background,
                        alignment: .center,
                        lineHeight: 1.1,
                        before: 24,
                        after: 6,
                        headIndent: 0,
                        firstLine: 0,
                        tailIndent: 0
                    )
                }

                if merged["Part Title"] == nil {
                    merged["Part Title"] = baseDefinition(
                        font: font,
                        size: partTitleSize,
                        bold: false,
                        italic: false,
                        color: color,
                        background: background,
                        alignment: .center,
                        lineHeight: 1.15,
                        before: 24,
                        after: 18,
                        headIndent: 0,
                        firstLine: 0,
                        tailIndent: 0
                    )
                }

                if merged["Part Subtitle"] == nil {
                    merged["Part Subtitle"] = baseDefinition(
                        font: font,
                        size: partSubtitleSize,
                        bold: false,
                        italic: false,
                        color: color,
                        background: background,
                        alignment: .center,
                        lineHeight: 1.15,
                        before: 0,
                        after: 18,
                        headIndent: 0,
                        firstLine: 0,
                        tailIndent: 0
                    )
                }

                // Tables (prose templates only; exclude Poetry/Screenplay templates).
                if merged["Table Title"] == nil {
                    merged["Table Title"] = baseDefinition(
                        font: font,
                        size: baseSize,
                        bold: true,
                        italic: false,
                        color: color,
                        background: background,
                        alignment: .center,
                        lineHeight: 1.15,
                        before: 12,
                        after: 6,
                        headIndent: 0,
                        firstLine: 0,
                        tailIndent: 0
                    )
                }
            }

            if merged["Heading 1"] == nil {
                merged["Heading 1"] = baseDefinition(
                    font: font,
                    size: h1Size,
                    bold: true,
                    italic: false,
                    color: color,
                    background: background,
                    alignment: .left,
                    lineHeight: 1.2,
                    before: 24,
                    after: 12,
                    headIndent: 0,
                    firstLine: 0,
                    tailIndent: 0
                )
            }

            if merged["Heading 2"] == nil {
                merged["Heading 2"] = baseDefinition(
                    font: font,
                    size: h2Size,
                    bold: true,
                    italic: false,
                    color: color,
                    background: background,
                    alignment: .left,
                    lineHeight: 1.2,
                    before: 18,
                    after: 6,
                    headIndent: 0,
                    firstLine: 0,
                    tailIndent: 0
                )
            }

            if merged["Heading 3"] == nil {
                merged["Heading 3"] = baseDefinition(
                    font: font,
                    size: h3Size,
                    bold: false,
                    italic: true,
                    color: color,
                    background: background,
                    alignment: .left,
                    lineHeight: 1.2,
                    before: 12,
                    after: 6,
                    headIndent: 0,
                    firstLine: 0,
                    tailIndent: 0
                )
            }

            if merged["Image Caption"] == nil {
                if let figureCaption = merged["Figure Caption"] {
                    merged["Image Caption"] = figureCaption
                } else {
                    merged["Image Caption"] = baseDefinition(
                        font: font,
                        size: captionSize,
                        bold: false,
                        italic: false,
                        color: color,
                        background: background,
                        alignment: .center,
                        lineHeight: 1.2,
                        before: 6,
                        after: 12,
                        headIndent: 0,
                        firstLine: 0,
                        tailIndent: 0
                    )
                }
            }

            // Optional semantic style used by some importers/flows to mark character cue lines
            // (primarily for fiction/prose workflows).
            if merged["Fiction — Character"] == nil {
                merged["Fiction — Character"] = baseDefinition(
                    font: font,
                    size: baseSize,
                    bold: true,
                    italic: false,
                    color: color,
                    background: background,
                    alignment: .left,
                    lineHeight: 1.2,
                    before: 12,
                    after: 0,
                    headIndent: 0,
                    firstLine: 0,
                    tailIndent: 0
                )
            }

            return merged
        }

        // Base style set for font-family templates.
        // We intentionally reuse the manuscript-oriented structure from the former "Fiction Manuscript" template,
        // but allow users to pick a font family directly via templates.
        let baseManuscript = fictionStyles()

        let minionPro = StyleTemplate(name: "Minion Pro", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Minion Pro"), includePartStyles: true))
        let arial = StyleTemplate(name: "Arial", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Arial"), includePartStyles: true))
        let timesNewRoman = StyleTemplate(name: "Times New Roman", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Times New Roman"), includePartStyles: true))
        let calibre = StyleTemplate(name: "Calibre", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Calibre"), includePartStyles: true))
        let inter = StyleTemplate(name: "Inter", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Inter"), includePartStyles: true))
        let helvetica = StyleTemplate(name: "Helvetica", styles: ensureStandardStyles(rebaseFonts(baseManuscript, fontFamily: "Helvetica"), includePartStyles: true))

        let poetry = StyleTemplate(
            name: "Poetry",
            styles: ensureStandardStyles(poetryStyles(), includePartStyles: false)
        )

        let screenplay = StyleTemplate(
            name: "Screenplay",
            styles: ensureStandardStyles(screenplayStyles(), includePartStyles: false)
        )
        let baskerville = StyleTemplate(
            name: "Baskerville Classic",
            styles: ensureStandardStyles(baskervilleStyles(), includePartStyles: true)
        )
        let garamond = StyleTemplate(
            name: "Garamond Elegant",
            styles: ensureStandardStyles(garamondStyles(), includePartStyles: true)
        )
        let palatino = StyleTemplate(
            name: "Palatino",
            styles: ensureStandardStyles(palatinoStyles(), includePartStyles: true)
        )
        let hoefler = StyleTemplate(
            name: "Hoefler Text",
            styles: ensureStandardStyles(hoeflerStyles(), includePartStyles: true)
        )
        let bradley = StyleTemplate(
            name: "Bradley Hand (Script)",
            styles: ensureStandardStyles(bradleyHandStyles(), includePartStyles: true)
        )
        let snell = StyleTemplate(
            name: "Snell Roundhand (Script)",
            styles: ensureStandardStyles(snellRoundhandStyles(), includePartStyles: true)
        )

        return [
            minionPro, arial, timesNewRoman, calibre, inter, helvetica,
            poetry, screenplay, baskerville, garamond, palatino, hoefler, bradley, snell
        ]
    }

    private static func poetryStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Times New Roman"

        // Verse is the writer-facing typographic style (applied to the lines the writer types).
        // Poet-friendly baseline with manuscript-leaning conventions.
        styles["Verse"] = baseDefinition(
            font: font,
            size: 20,
            alignment: .left,
            lineHeight: 1.5,
            before: 0,
            after: 0,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Poem is structural (container). We keep it for back-compat, but it should not appear in the UI picker.
        // If a legacy document has "Poem" applied to lines, we render it like Verse.
        styles["Poem"] = styles["Verse"]

        // Legacy/structural alias kept for existing documents/importers.
        styles["Stanza"] = styles["Verse"]

        styles["Poem Title"] = baseDefinition(
            font: font,
            size: 24,
            bold: true,
            alignment: .center,
            lineHeight: 1.15,
            before: 24,
            after: 12,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Requested: front-matter style aliases
        // (Use existing Poetry naming where possible, but expose canonical names in the picker.)
        styles["Title"] = styles["Poem Title"]

        styles["Poet Name"] = baseDefinition(
            font: font,
            size: 20,
            alignment: .center,
            lineHeight: 1.15,
            before: 0,
            after: 18,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Structural
        styles["Section / Sequence Title"] = baseDefinition(
            font: font,
            size: 20,
            bold: true,
            alignment: .center,
            lineHeight: 1.15,
            before: 18,
            after: 12,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        styles["Part Number"] = baseDefinition(
            font: font,
            size: 20,
            bold: true,
            alignment: .center,
            lineHeight: 1.1,
            before: 24,
            after: 12,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Inline persona / speaker voice (often used for rhetorical asides or stage-direction-like lines)
        styles["Voice"] = baseDefinition(
            font: font,
            size: 20,
            italic: true,
            alignment: .left,
            lineHeight: 1.5,
            before: 0,
            after: 0,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Auxiliary
        styles["Epigraph"] = baseDefinition(
            font: font,
            size: 20,
            italic: true,
            alignment: .left,
            lineHeight: 1.35,
            before: 12,
            after: 12,
            headIndent: 24,
            firstLine: 24,
            tailIndent: -24
        )

        styles["Dedication"] = baseDefinition(
            font: font,
            size: 20,
            italic: true,
            alignment: .center,
            lineHeight: 1.2,
            before: 12,
            after: 12,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Argument (prose-like; no stanza breaks / poetic spacing by default)
        styles["Argument Title"] = baseDefinition(
            font: font,
            size: 18,
            smallCaps: true,
            alignment: .center,
            lineHeight: 1.15,
            before: 18,
            after: 10,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )
        styles["Argument"] = baseDefinition(
            font: font,
            size: 18,
            italic: true,
            alignment: .justified,
            lineHeight: 1.25,
            before: 0,
            after: 8,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Verse-level variants
        styles["Refrain"] = baseDefinition(
            font: font,
            size: 20,
            italic: true,
            alignment: .left,
            lineHeight: 1.5,
            before: 0,
            after: 0,
            headIndent: 18,
            firstLine: 0,
            tailIndent: 0
        )
        styles["Chorus"] = baseDefinition(
            font: font,
            size: 20,
            italic: true,
            alignment: .center,
            lineHeight: 1.5,
            before: 0,
            after: 0,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )
        styles["Speaker"] = baseDefinition(
            font: font,
            size: 18,
            smallCaps: true,
            alignment: .left,
            lineHeight: 1.2,
            before: 10,
            after: 4,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        styles["Section Break"] = baseDefinition(
            font: font,
            size: 18,
            alignment: .center,
            lineHeight: 1.0,
            before: 12,
            after: 12,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Verse/prose hybrids
        styles["Prose Poem"] = baseDefinition(
            font: font,
            size: 18,
            italic: true,
            alignment: .justified,
            lineHeight: 1.25,
            before: 0,
            after: 8,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )
        styles["Verse Paragraph"] = baseDefinition(
            font: font,
            size: 20,
            alignment: .left,
            lineHeight: 1.5,
            before: 0,
            after: 8,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        styles["Notes"] = baseDefinition(
            font: font,
            size: 16,
            alignment: .left,
            lineHeight: 1.35,
            before: 12,
            after: 6,
            headIndent: 18,
            firstLine: 0,
            tailIndent: 0
        )

        // Editorial
        styles["Draft / Margin Note"] = baseDefinition(
            font: font,
            size: 16,
            italic: true,
            color: "#6B6B6B",
            alignment: .left,
            lineHeight: 1.25,
            before: 6,
            after: 6,
            headIndent: 18,
            firstLine: 0,
            tailIndent: 0
        )

        styles["Marginal Note"] = styles["Draft / Margin Note"]

        styles["Footnote"] = baseDefinition(
            font: font,
            size: 14,
            alignment: .left,
            lineHeight: 1.2,
            before: 6,
            after: 6,
            headIndent: 18,
            firstLine: 0,
            tailIndent: 0
        )

        styles["Revision Variant"] = baseDefinition(
            font: font,
            size: 16,
            italic: true,
            color: "#4B4B6B",
            alignment: .left,
            lineHeight: 1.25,
            before: 6,
            after: 6,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // Poetry style keys
        styles["Poetry — Title"] = styles["Poem Title"]
        // Internal/compat keys kept for old docs/importers.
        styles["Poetry — Stanza"] = styles["Verse"]
        // Legacy name kept for backwards compatibility with existing documents/importers.
        styles["Poetry — Verse"] = styles["Verse"]
        styles["Poetry — Stanza Break"] = baseDefinition(
            font: font,
            size: 20,
            alignment: .left,
            lineHeight: 1.0,
            before: 0,
            after: 18,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )
        styles["Poetry — Author"] = baseDefinition(
            font: font,
            size: 20,
            alignment: .center,
            lineHeight: 1.15,
            before: 6,
            after: 18,
            headIndent: 0,
            firstLine: 0,
            tailIndent: 0
        )

        // More explicit alias (helps UI and importers)
        styles["Author"] = styles["Poet Name"]
        styles["Poetry — Poet Name"] = styles["Poet Name"]

        // Internal defaults for import/export paths that still refer to Body Text.
        styles["Body Text"] = styles["Verse"]
        styles["Body Text – No Indent"] = styles["Verse"]

        return styles
    }

    private static func baseDefinition(
        font: String,
        size: CGFloat,
        bold: Bool = false,
        italic: Bool = false,
        smallCaps: Bool = false,
        color: String = "#1F1B1A",
        background: String? = nil,
        alignment: NSTextAlignment = .left,
        lineHeight: CGFloat = 2.0,
        before: CGFloat = 0,
        after: CGFloat = 0,
        headIndent: CGFloat = 0,
        firstLine: CGFloat = 36,
        tailIndent: CGFloat = 0
    ) -> StyleDefinition {
        StyleDefinition(
            fontName: font,
            fontSize: size,
            isBold: bold,
            isItalic: italic,
            useSmallCaps: smallCaps,
            textColorHex: color,
            backgroundColorHex: background,
            alignmentRawValue: alignment.rawValue,
            lineHeightMultiple: lineHeight,
            spacingBefore: before,
            spacingAfter: after,
            headIndent: headIndent,
            firstLineIndent: firstLine,
            tailIndent: tailIndent
        )
    }

    private static func fictionStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        styles["Body Text"] = baseDefinition(font: "Times New Roman", size: 14)
        styles["Body Text – No Indent"] = baseDefinition(font: "Times New Roman", size: 14, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: "Times New Roman", size: 24, bold: false, alignment: .center, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: "Times New Roman", size: 16, alignment: .center, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .center, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Front Matter Heading"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .left, before: 24, after: 12, headIndent: 0, firstLine: 0)
        styles["Epigraph"] = baseDefinition(font: "Times New Roman", size: 12, italic: true, alignment: .left, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .right, before: 6, after: 18, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Part Title"] = baseDefinition(font: "Times New Roman", size: 20, alignment: .center, before: 24, after: 18, headIndent: 0, firstLine: 0)
        styles["Part Subtitle"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .center, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .center, before: 24, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: "Times New Roman", size: 18, alignment: .center, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .center, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Heading 1"] = baseDefinition(font: "Times New Roman", size: 14, bold: true, alignment: .left, before: 24, after: 12, headIndent: 0, firstLine: 0)
        styles["Heading 2"] = baseDefinition(font: "Times New Roman", size: 13, bold: true, alignment: .left, before: 18, after: 6, headIndent: 0, firstLine: 0)
        styles["Heading 3"] = baseDefinition(font: "Times New Roman", size: 12, italic: true, alignment: .left, before: 12, after: 6, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .center, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: "Times New Roman", size: 12, italic: true)
        styles["Letter / Document"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .left, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Block Quote"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .left, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Block Quote Attribution"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .right, before: 6, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Sidebar"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .left, lineHeight: 1.2, before: 12, after: 12, headIndent: 18, firstLine: 18, tailIndent: -18)
        styles["Back Matter Heading"] = baseDefinition(font: "Times New Roman", size: 14, alignment: .left, before: 24, after: 12, headIndent: 0, firstLine: 0)
        styles["Notes Entry"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .left, lineHeight: 1.2, before: 0, after: 6, headIndent: 18, firstLine: 0, tailIndent: 0)
        styles["Bibliography Entry"] = styles["Notes Entry"]
        styles["Index Entry"] = styles["Notes Entry"]
        styles["Callout"] = baseDefinition(font: "Times New Roman", size: 11, italic: true, alignment: .left, lineHeight: 1.0, before: 12, after: 12, headIndent: 18, firstLine: 18, tailIndent: -18)
        styles["Figure Caption"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .left, lineHeight: 1.0, before: 6, after: 12, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Table Caption"] = styles["Figure Caption"]
        styles["Footnote / Endnote"] = baseDefinition(font: "Times New Roman", size: 10, alignment: .left, lineHeight: 1.0, before: 6, after: 6, headIndent: 0, firstLine: 0, tailIndent: 0)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: "Times New Roman", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: "Times New Roman", size: 14, bold: true, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: "Times New Roman", size: 11, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: "Times New Roman", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: "Times New Roman", size: 14, bold: true, alignment: .left, lineHeight: 1.4, before: 12, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: "Times New Roman", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: "Times New Roman", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: "Times New Roman", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 18, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func nonfictionStyles() -> [String: StyleDefinition] {
        var styles = fictionStyles()
        styles["Body Text"] = baseDefinition(font: "Georgia", size: 14, lineHeight: 1.6, headIndent: 0, firstLine: 24)
        styles["Body Text – No Indent"] = baseDefinition(font: "Georgia", size: 14, lineHeight: 1.6, headIndent: 0, firstLine: 0)
        styles["Heading 1"] = baseDefinition(font: "Georgia", size: 16, bold: true, alignment: .left, lineHeight: 1.2, before: 18, after: 8, headIndent: 0, firstLine: 0)
        styles["Heading 2"] = baseDefinition(font: "Georgia", size: 14, bold: true, alignment: .left, lineHeight: 1.2, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Heading 3"] = baseDefinition(font: "Georgia", size: 12, italic: true, alignment: .left, lineHeight: 1.2, before: 10, after: 4, headIndent: 0, firstLine: 0)
        styles["Sidebar"] = baseDefinition(font: "Georgia", size: 11, alignment: .left, lineHeight: 1.2, before: 10, after: 10, headIndent: 18, firstLine: 18, tailIndent: -18)
        styles["Callout"] = baseDefinition(font: "Georgia", size: 11, italic: true, alignment: .left, lineHeight: 1.1, before: 10, after: 10, headIndent: 18, firstLine: 18, tailIndent: -18)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: "Georgia", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: "Georgia", size: 14, bold: true, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: "Georgia", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: "Georgia", size: 11, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: "Georgia", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: "Georgia", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: "Georgia", size: 14, bold: true, alignment: .left, lineHeight: 1.4, before: 12, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: "Georgia", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: "Georgia", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: "Georgia", size: 12, alignment: .left, lineHeight: 1.4, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: "Georgia", size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 18, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func screenplayStyles() -> [String: StyleDefinition] {
        let font = "Courier New"
        var styles: [String: StyleDefinition] = [:]
        // Title page styles
        styles["Screenplay — Title"] = baseDefinition(font: font, size: 18, bold: true, alignment: .center, lineHeight: 1.0, before: 144, after: 12, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Author"] = baseDefinition(font: font, size: 12, alignment: .center, lineHeight: 1.0, before: 72, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Contact"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 0, firstLine: 0, tailIndent: -288)
        styles["Screenplay — Draft"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.0, before: 0, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        // Script body styles
        // Act headings (e.g. ACT I / ACT II / ACT III)
        styles["Screenplay — Act"] = baseDefinition(font: font, size: 14, bold: true, alignment: .center, lineHeight: 1.0, before: 24, after: 12, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Slugline"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        // No-indent body style (useful for blank spacer lines between screenplay styles)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Action"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Character"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 158, firstLine: 158, tailIndent: -72)
        styles["Screenplay — Parenthetical"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 115, firstLine: 115, tailIndent: -72)
        styles["Screenplay — Dialogue"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 72, firstLine: 72, tailIndent: -72)
        styles["Screenplay — Transition"] = baseDefinition(font: font, size: 14, alignment: .right, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Shot"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        return styles
    }

    func getAllStyles() -> [String: StyleDefinition] {
        let overrides = loadOverrides(for: currentTemplateName)
        var allStyles = templates[currentTemplateName]?.styles ?? [:]
        for (key, value) in overrides {
            allStyles[key] = value
        }
        return allStyles
    }

    private static func baskervilleStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Baskerville"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.8)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.8, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 28, bold: false, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 18, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 36, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 16, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 20, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func garamondStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Garamond"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.75)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.75, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 26, bold: false, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 17, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 30, after: 10, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 15, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 16, after: 16, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.75)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 20, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func palatinoStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Palatino"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.8)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.8, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 17, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 15, alignment: .center, lineHeight: 1.2, before: 32, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 15, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 13, alignment: .center, lineHeight: 1.2, before: 16, after: 16, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 13, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 12, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 11, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 13, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 11, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 13, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 20, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 20, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func hoeflerStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Hoefler Text"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.7)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.7, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 30, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 18, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 15, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 36, after: 14, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 16, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.7)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 22, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 22, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 14, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 22, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 22, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 22, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func bradleyHandStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Bradley Hand"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.8)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.8, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 32, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 20, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 18, alignment: .center, lineHeight: 1.2, before: 36, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 15, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 24, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 16, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 24, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 16, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 24, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 24, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 22, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func snellRoundhandStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Snell Roundhand"
        styles["Body Text"] = baseDefinition(font: font, size: 14, lineHeight: 1.9)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 14, lineHeight: 1.9, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 34, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 26, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 22, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 17, alignment: .center, lineHeight: 1.2, before: 0, after: 14, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 19, alignment: .center, lineHeight: 1.2, before: 38, after: 14, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 18, bold: true, alignment: .center, lineHeight: 1.2, before: 60, after: 24, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 20, after: 20, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 15, italic: true, lineHeight: 1.9)
        styles["Block Quote"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.7, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        // TOC and Index styles
        styles["TOC Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 1"] = baseDefinition(font: font, size: 16, bold: true, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["TOC Entry Level 2"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["TOC Entry Level 3"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 40, firstLine: 40)
        styles["TOC Entry"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 0, firstLine: 0)
        styles["Index Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Index Letter"] = baseDefinition(font: font, size: 16, bold: true, alignment: .left, lineHeight: 1.5, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Index Entry"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 0, headIndent: 20, firstLine: 20)
        styles["Glossary Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Glossary Entry"] = baseDefinition(font: font, size: 15, alignment: .left, lineHeight: 1.5, before: 0, after: 6, headIndent: 0, firstLine: 0)
        styles["Appendix Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 24, after: 24, headIndent: 0, firstLine: 0)
        return styles
    }
}
