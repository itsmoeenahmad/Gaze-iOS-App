import Foundation
import os

// MARK: - Log Category

enum LogCategory: String {
    case api      = "API"
    case auth     = "Auth"
    case feed     = "Feed"
    case post     = "Post"
    case profile  = "Profile"
    case social   = "Social"
    case comments = "Comments"
}

// MARK: - App Logger

/// Centralized, production-safe logger built on OSLog.
///
/// Usage:
///   AppLogger.info("Feed loaded", category: .feed, properties: ["count": "\(items.count)"])
///   AppLogger.error("Insert failed", category: .api, properties: ["error": error.localizedDescription])
///
/// Debug-level logs are stripped from release builds.
struct AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.gaze.app"

    private static let loggers: [LogCategory: Logger] = {
        var map = [LogCategory: Logger]()
        for cat in [LogCategory.api, .auth, .feed, .post, .profile, .social, .comments] {
            map[cat] = Logger(subsystem: subsystem, category: cat.rawValue)
        }
        return map
    }()

    // MARK: - Public API

    static func debug(
        _ message: String,
        category: LogCategory = .api,
        properties: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(.debug, message, category: category, properties: properties,
            file: file, function: function, line: line)
        #endif
    }

    static func info(
        _ message: String,
        category: LogCategory = .api,
        properties: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message, category: category, properties: properties,
            file: file, function: function, line: line)
    }

    static func warning(
        _ message: String,
        category: LogCategory = .api,
        properties: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message, category: category, properties: properties,
            file: file, function: function, line: line)
    }

    static func error(
        _ message: String,
        category: LogCategory = .api,
        properties: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message, category: category, properties: properties,
            file: file, function: function, line: line)
    }

    // MARK: - Internal

    private enum Level: String {
        case debug   = "DEBUG"
        case info    = "INFO"
        case warning = "WARN"
        case error   = "ERROR"
    }

    private static func log(
        _ level: Level,
        _ message: String,
        category: LogCategory,
        properties: [String: String]?,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        var formatted = "[\(level.rawValue)] \(fileName):\(line) \(function) | \(message)"

        if let props = properties, !props.isEmpty {
            let pairs = props.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " | ")
            formatted += " | \(pairs)"
        }

        let logger = loggers[category] ?? Logger(subsystem: subsystem, category: category.rawValue)

        switch level {
        case .debug:   logger.debug("\(formatted, privacy: .public)")
        case .info:    logger.info("\(formatted, privacy: .public)")
        case .warning: logger.warning("\(formatted, privacy: .public)")
        case .error:   logger.error("\(formatted, privacy: .public)")
        }
    }
}
