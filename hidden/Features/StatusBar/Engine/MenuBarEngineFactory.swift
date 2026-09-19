//
//  MenuBarEngineFactory.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import Foundation

// The single place that picks a hiding mechanism for the running OS.
enum MenuBarEngineFactory {
    static func make(items: MenuBarItemProvider) -> MenuBarEngine {
        // macOS 27 ejects an inflated separator from the menu bar (#360). When the
        // native visibility API is available (direct, non-sandboxed build on 27) we
        // hide natively instead — independent of display width, notch and the
        // frontmost app's menus. Otherwise we fall back to the legacy length engine
        // with its macOS 27 spacer block.
        #if HIDDENBAR_NATIVE_VISIBILITY
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            return NativeVisibilityEngine(items: items)
        }
        #endif
        return LegacyLengthEngine(items: items)
    }
}
