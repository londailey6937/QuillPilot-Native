import Foundation

enum DebugLog {
    @inline(__always)
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("%@", message())
        #endif
    }
}
