import Foundation
import os

/// Тонкая обёртка над os.Logger c единым subsystem.
enum Log {
    private static let subsystem = "com.golos.app"
    static let coordinator = Logger(subsystem: subsystem, category: "coordinator")
    static let hotkeys     = Logger(subsystem: subsystem, category: "hotkeys")
    static let audio       = Logger(subsystem: subsystem, category: "audio")
    static let sidecar     = Logger(subsystem: subsystem, category: "sidecar")
    static let injection   = Logger(subsystem: subsystem, category: "injection")
    static let model       = Logger(subsystem: subsystem, category: "model")
    static let ui          = Logger(subsystem: subsystem, category: "ui")
}
