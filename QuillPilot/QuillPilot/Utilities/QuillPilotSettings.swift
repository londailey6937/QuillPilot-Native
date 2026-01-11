import Foundation

enum QuillPilotSettings {
    private enum Keys {
        static let autoSaveIntervalSeconds = "QuillPilot.autoSaveIntervalSeconds"
        static let defaultExportFormat = "QuillPilot.defaultExportFormat"
        static let autoAnalyzeOnOpen = "QuillPilot.autoAnalyzeOnOpen"
        static let autoAnalyzeWhileTyping = "QuillPilot.autoAnalyzeWhileTyping"
    }

    static var autoSaveIntervalSeconds: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoSaveIntervalSeconds) == nil {
                return 30.0
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
}

extension Notification.Name {
    static let quillPilotSettingsDidChange = Notification.Name("quillPilotSettingsDidChange")
}
