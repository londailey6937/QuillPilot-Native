import Foundation

enum DebugLog {
    static var enabled: Bool {
        #if DEBUG
        return true
        #else
        if ProcessInfo.processInfo.environment["QP_DEBUG_LOG"] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: "QPDebugLog")
        #endif
    }

    @inline(__always)
    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        NSLog("%@", message())
    }
}

@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    guard DebugLog.enabled else { return }
    NSLog("%@", message())
}
