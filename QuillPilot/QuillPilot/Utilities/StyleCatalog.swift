import Cocoa

struct StyleDefinition: Codable {
    var fontName: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var textColorHex: String
    var backgroundColorHex: String?
    var alignmentRawValue: Int
    var lineHeightMultiple: CGFloat
    var spacingBefore: CGFloat
    var spacingAfter: CGFloat
    var headIndent: CGFloat
    var firstLineIndent: CGFloat
    var tailIndent: CGFloat
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
        templates[templateName]?.styles.keys.map { $0 }.sorted() ?? []
    }

    func setCurrentTemplate(_ name: String) {
        guard templates[name] != nil else { return }
        currentTemplateName = name
        defaults.set(name, forKey: templateKey)
    }

    func style(named name: String) -> StyleDefinition? {
        let overrides = loadOverrides(for: currentTemplateName)
        if let override = overrides[name] { return override }
        return templates[currentTemplateName]?.styles[name]
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
        let fiction = StyleTemplate(
            name: "Fiction Manuscript",
            styles: fictionStyles()
        )
        let nonfiction = StyleTemplate(
            name: "Non-Fiction",
            styles: nonfictionStyles()
        )
        let screenplay = StyleTemplate(
            name: "Screenplay",
            styles: screenplayStyles()
        )
        let baskerville = StyleTemplate(
            name: "Baskerville Classic",
            styles: baskervilleStyles()
        )
        let garamond = StyleTemplate(
            name: "Garamond Elegant",
            styles: garamondStyles()
        )
        let palatino = StyleTemplate(
            name: "Palatino",
            styles: palatinoStyles()
        )
        let hoefler = StyleTemplate(
            name: "Hoefler Text",
            styles: hoeflerStyles()
        )
        let bradley = StyleTemplate(
            name: "Bradley Hand (Script)",
            styles: bradleyHandStyles()
        )
        let snell = StyleTemplate(
            name: "Snell Roundhand (Script)",
            styles: snellRoundhandStyles()
        )
        return [fiction, nonfiction, screenplay, baskerville, garamond, palatino, hoefler, bradley, snell]
    }

    private static func baseDefinition(
        font: String,
        size: CGFloat,
        bold: Bool = false,
        italic: Bool = false,
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
        styles["Chapter Title"] = baseDefinition(font: "Times New Roman", size: 18, alignment: .center, before: 0, after: 0, headIndent: 0, firstLine: 0)
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
        return styles
    }

    private static func nonfictionStyles() -> [String: StyleDefinition] {
        var styles = fictionStyles()
        styles["Body Text"] = baseDefinition(font: "Georgia", size: 11, lineHeight: 1.6, headIndent: 0, firstLine: 24)
        styles["Body Text – No Indent"] = baseDefinition(font: "Georgia", size: 11, lineHeight: 1.6, headIndent: 0, firstLine: 0)
        styles["Heading 1"] = baseDefinition(font: "Georgia", size: 16, bold: true, alignment: .left, lineHeight: 1.2, before: 18, after: 8, headIndent: 0, firstLine: 0)
        styles["Heading 2"] = baseDefinition(font: "Georgia", size: 14, bold: true, alignment: .left, lineHeight: 1.2, before: 14, after: 6, headIndent: 0, firstLine: 0)
        styles["Heading 3"] = baseDefinition(font: "Georgia", size: 12, italic: true, alignment: .left, lineHeight: 1.2, before: 10, after: 4, headIndent: 0, firstLine: 0)
        styles["Sidebar"] = baseDefinition(font: "Georgia", size: 11, alignment: .left, lineHeight: 1.2, before: 10, after: 10, headIndent: 18, firstLine: 18, tailIndent: -18)
        styles["Callout"] = baseDefinition(font: "Georgia", size: 11, italic: true, alignment: .left, lineHeight: 1.1, before: 10, after: 10, headIndent: 18, firstLine: 18, tailIndent: -18)
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
        styles["Screenplay — Slugline"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Action"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Character"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 158, firstLine: 158, tailIndent: -72)
        styles["Screenplay — Parenthetical"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 115, firstLine: 115, tailIndent: -72)
        styles["Screenplay — Dialogue"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 0, after: 0, headIndent: 72, firstLine: 72, tailIndent: -72)
        styles["Screenplay — Transition"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
        styles["Screenplay — Shot"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.0, before: 12, after: 0, headIndent: 0, firstLine: 0, tailIndent: 0)
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
        styles["Chapter Title"] = baseDefinition(font: font, size: 22, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 16, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
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
        styles["Chapter Title"] = baseDefinition(font: font, size: 20, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 15, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 16, after: 16, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.75)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func palatinoStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Palatino"
        styles["Body Text"] = baseDefinition(font: font, size: 13, lineHeight: 1.8)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 13, lineHeight: 1.8, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 17, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 15, alignment: .center, lineHeight: 1.2, before: 32, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 21, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 22, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 15, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 16, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 13, alignment: .center, lineHeight: 1.2, before: 16, after: 16, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 13, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 12, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 12, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 11, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
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
        styles["Chapter Title"] = baseDefinition(font: font, size: 24, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Chapter Subtitle"] = baseDefinition(font: font, size: 16, italic: true, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 14, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 14, italic: true, lineHeight: 1.7)
        styles["Block Quote"] = baseDefinition(font: font, size: 13, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 13, italic: true, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph Attribution"] = baseDefinition(font: font, size: 12, alignment: .right, lineHeight: 1.2, before: 6, after: 18, headIndent: 0, firstLine: 0)
        return styles
    }

    private static func bradleyHandStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Bradley Hand"
        styles["Body Text"] = baseDefinition(font: font, size: 16, lineHeight: 1.8)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 16, lineHeight: 1.8, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 32, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 20, alignment: .center, lineHeight: 1.2, before: 0, after: 18, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 0, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 18, alignment: .center, lineHeight: 1.2, before: 36, after: 12, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 26, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 24, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 18, after: 18, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 15, italic: true, lineHeight: 1.8)
        styles["Block Quote"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.5, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        return styles
    }

    private static func snellRoundhandStyles() -> [String: StyleDefinition] {
        var styles: [String: StyleDefinition] = [:]
        let font = "Snell Roundhand"
        styles["Body Text"] = baseDefinition(font: font, size: 16, lineHeight: 1.9)
        styles["Body Text – No Indent"] = baseDefinition(font: font, size: 16, lineHeight: 1.9, firstLine: 0)
        styles["Book Title"] = baseDefinition(font: font, size: 34, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 26, headIndent: 0, firstLine: 0)
        styles["Book Subtitle"] = baseDefinition(font: font, size: 22, alignment: .center, lineHeight: 1.2, before: 0, after: 20, headIndent: 0, firstLine: 0)
        styles["Author Name"] = baseDefinition(font: font, size: 17, alignment: .center, lineHeight: 1.2, before: 0, after: 14, headIndent: 0, firstLine: 0)
        styles["Chapter Number"] = baseDefinition(font: font, size: 19, alignment: .center, lineHeight: 1.2, before: 38, after: 14, headIndent: 0, firstLine: 0)
        styles["Chapter Title"] = baseDefinition(font: font, size: 28, bold: true, alignment: .center, lineHeight: 1.2, before: 0, after: 26, headIndent: 0, firstLine: 0)
        styles["Scene Break"] = baseDefinition(font: font, size: 16, alignment: .center, lineHeight: 1.2, before: 20, after: 20, headIndent: 0, firstLine: 0)
        styles["Dialogue"] = styles["Body Text"]
        styles["Internal Thought"] = baseDefinition(font: font, size: 15, italic: true, lineHeight: 1.9)
        styles["Block Quote"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.7, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        styles["Epigraph"] = baseDefinition(font: font, size: 14, alignment: .left, lineHeight: 1.6, before: 12, after: 12, headIndent: 36, firstLine: 36, tailIndent: -36)
        return styles
    }
}
