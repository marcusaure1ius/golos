import Foundation

/// Пути, которые приложение использует для своих ресурсов.
enum AppPaths {
    /// `~/Library/Application Support/golos/`
    static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("golos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Корень для хранения скачанных моделей.
    static var modelsRoot: URL {
        let dir = appSupport.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Каталог конкретной модели.
    static func modelDir(_ revision: String) -> URL {
        let dir = modelsRoot.appendingPathComponent(revision, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Sidecar binary внутри bundle.
    static var sidecarBinary: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/golos-asr")
    }

    /// Файл логов.
    static var logFile: URL {
        appSupport.appendingPathComponent("golos.log")
    }

    /// Файл хранилища истории транскрипций.
    static var historyFile: URL {
        appSupport.appendingPathComponent("history.json")
    }

    /// Файл хранилища статистики.
    static var statsFile: URL {
        appSupport.appendingPathComponent("stats.json")
    }
}
