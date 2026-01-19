import Foundation

enum QuillPilotSettings {
    private enum Keys {
        static let autoSaveIntervalSeconds = "QuillPilot.autoSaveIntervalSeconds"
        static let defaultExportFormat = "QuillPilot.defaultExportFormat"
        static let autoAnalyzeOnOpen = "QuillPilot.autoAnalyzeOnOpen"
        static let autoAnalyzeWhileTyping = "QuillPilot.autoAnalyzeWhileTyping"
        static let autoNumberOnReturn = "QuillPilot.autoNumberOnReturn"
        static let numberingScheme = "QuillPilot.numberingScheme"
    }

    enum NumberingScheme: String, CaseIterable {
        case decimalDotted = "decimalDotted"
        case alphabetUpper = "alphabetUpper"
        case alphabetLower = "alphabetLower"

        var displayName: String {
            switch self {
            case .decimalDotted:
                return "1.1.1"
            case .alphabetUpper:
                return "A. B. C."
            case .alphabetLower:
                return "a. b. c."
            }
        }
    }

    static var autoSaveIntervalSeconds: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoSaveIntervalSeconds) == nil {
                // Default to a practical cadence that won't churn disks while writing.
                return 60.0
            }
            let v = UserDefaults.standard.double(forKey: Keys.autoSaveIntervalSeconds)
            return max(0, v)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoSaveIntervalSeconds)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }

    static var defaultExportFormat: ExportFormat {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.defaultExportFormat),
               let format = ExportFormat(rawValue: raw) {
                return format
            }
            return .docx
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.defaultExportFormat)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }

    static var autoAnalyzeOnOpen: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoAnalyzeOnOpen) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.autoAnalyzeOnOpen)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoAnalyzeOnOpen)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }

    static var autoAnalyzeWhileTyping: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoAnalyzeWhileTyping) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.autoAnalyzeWhileTyping)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoAnalyzeWhileTyping)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }

    static var autoNumberOnReturn: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoNumberOnReturn) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.autoNumberOnReturn)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoNumberOnReturn)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }

    static var numberingScheme: NumberingScheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.numberingScheme),
               let scheme = NumberingScheme(rawValue: raw) {
                return scheme
            }
            return .decimalDotted
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.numberingScheme)
            NotificationCenter.default.post(name: .quillPilotSettingsDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let quillPilotSettingsDidChange = Notification.Name("quillPilotSettingsDidChange")
}
