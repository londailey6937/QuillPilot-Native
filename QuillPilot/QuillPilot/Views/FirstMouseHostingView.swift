//
//  FirstMouseHostingView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2026 QuillPilot. All rights reserved.
//

import SwiftUI
import Cocoa

/// NSHostingView that accepts first mouse click even when window is inactive.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
