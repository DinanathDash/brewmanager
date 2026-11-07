//
//  BrewLogger.swift
//  Brewmanager
//
//  Thread-safe rotating file logger for Brew Manager with auto-purge
//  and non-modal log export.
//

import AppKit
import Foundation

public enum BrewLogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case error = "ERROR"
}

public final class BrewLogger: @unchecked Sendable {
    public static let shared = BrewLogger()

    public static var defaultLogDirectory: URL {
        let libraryLogs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return libraryLogs.appendingPathComponent("Logs/Brewmanager")
    }

    private let logDirectory: URL
    private let fileName: String
    private let maxFileSize: UInt64
    private let maxBackups: Int
    private let maxAgeDays: Double

    private let queue = DispatchQueue(
        label: "com.brewmanager.log.fileappender",
        qos: .utility
    )
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public init(
        logDirectory: URL? = nil,
        fileName: String = "brewmanager.log",
        maxFileSize: UInt64 = 5 * 1024 * 1024,
        maxBackups: Int = 3,
        maxAgeDays: Double = 7.0
    ) {
        self.logDirectory = logDirectory ?? Self.defaultLogDirectory
        self.fileName = fileName
        self.maxFileSize = max(maxFileSize, 50)
        self.maxBackups = max(maxBackups, 0)
        self.maxAgeDays = max(maxAgeDays, 0.1)

        queue.sync {
            self.prepareLogFile()
            self.purgeOldLogs()
        }
    }

    deinit {
        let handle = fileHandle
        queue.async {
            try? handle?.synchronize()
            try? handle?.close()
        }
    }

    public func log(_ level: BrewLogLevel, _ message: String) {
        let now = Date()
        queue.async { [weak self] in
            guard let self else { return }
            let formattedDate = self.dateFormatter.string(from: now)
            let line = "\(formattedDate) [\(level.rawValue)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            self.write(data)
        }
    }

    public func debug(_ message: String) { log(.debug, message) }
    public func info(_ message: String) { log(.info, message) }
    public func notice(_ message: String) { log(.notice, message) }
    public func error(_ message: String) { log(.error, message) }

    public func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    public func purgeAll() {
        queue.sync {
            try? fileHandle?.close()
            fileHandle = nil
            currentFileSize = 0
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.hasPrefix("brewmanager") {
                    try? fm.removeItem(at: file)
                }
            }
            prepareLogFile()
        }
    }

    private var currentFileURL: URL {
        logDirectory.appendingPathComponent(fileName)
    }

    private func backupFileURL(index: Int) -> URL {
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let backupName = ext.isEmpty ? "\(baseName).\(index)" : "\(baseName).\(index).\(ext)"
        return logDirectory.appendingPathComponent(backupName)
    }

    private func prepareLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }

        let fileURL = currentFileURL
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            handle.seekToEndOfFile()
            self.fileHandle = handle
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            self.currentFileSize = attributes[.size] as? UInt64 ?? 0
        } catch {
            self.fileHandle = nil
            self.currentFileSize = 0
        }
    }

    private func write(_ data: Data) {
        if currentFileSize + UInt64(data.count) > maxFileSize {
            rotate()
        }

        if fileHandle == nil {
            prepareLogFile()
        }

        guard let fileHandle else { return }

        do {
            try fileHandle.write(contentsOf: data)
            currentFileSize += UInt64(data.count)
        } catch {
            try? fileHandle.close()
            self.fileHandle = nil
        }
    }

    private func rotate() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil

        let fileManager = FileManager.default

        let highestBackup = backupFileURL(index: maxBackups)
        if fileManager.fileExists(atPath: highestBackup.path) {
            try? fileManager.removeItem(at: highestBackup)
        }

        if maxBackups > 1 {
            for i in stride(from: maxBackups - 1, through: 1, by: -1) {
                let src = backupFileURL(index: i)
                let dst = backupFileURL(index: i + 1)
                if fileManager.fileExists(atPath: src.path) {
                    try? fileManager.moveItem(at: src, to: dst)
                }
            }
        }

        let current = currentFileURL
        if fileManager.fileExists(atPath: current.path) {
            if maxBackups > 0 {
                let backup1 = backupFileURL(index: 1)
                try? fileManager.moveItem(at: current, to: backup1)
            } else {
                try? fileManager.removeItem(at: current)
            }
        }

        prepareLogFile()
        purgeOldLogs()
    }

    private func purgeOldLogs() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoffDate = Date().addingTimeInterval(-maxAgeDays * 86400)
        for file in files where file.lastPathComponent.hasPrefix("brewmanager") {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

// MARK: - Log Exporter

@MainActor
public enum BrewLogExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func exportLogs(
        from directory: URL = BrewLogger.defaultLogDirectory,
        date: Date = Date()
    ) async throws -> URL {
        BrewLogger.shared.flush()

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            throw NSError(domain: "BrewLogExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No log directory found"])
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let logFiles = contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("brewmanager") && (name.hasSuffix(".log") || name.contains(".log."))
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !logFiles.isEmpty else {
            throw NSError(domain: "BrewLogExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No log files found to export."])
        }

        let dateString = dateFormatter.string(from: date)
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let archiveName = "BrewManager-Logs-\(dateString)-\(uniqueSuffix).zip"
        let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(archiveName)

        if fileManager.fileExists(atPath: archiveURL.path) {
            try? fileManager.removeItem(at: archiveURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-j", archiveURL.path] + logFiles.map(\.path)
        try process.run()
        process.waitUntilExit()

        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw NSError(domain: "BrewLogExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Zip archive could not be created."])
        }

        return archiveURL
    }

    public static func showLogsInFinder(directory: URL = BrewLogger.defaultLogDirectory) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }

    /// Presents a non-modal save panel using `panel.begin { ... }` so Droppy's main thread is NEVER blocked.
    public static func promptExportLogs(window: NSWindow? = nil, completion: (@Sendable (Bool) -> Void)? = nil) {
        Task { @MainActor in
            do {
                let tempZip = try await exportLogs()
                let panel = NSSavePanel()
                panel.title = "Export Brew Manager Logs"
                panel.nameFieldStringValue = tempZip.lastPathComponent
                panel.canCreateDirectories = true

                // CRITICAL FIX: Use panel.begin rather than panel.runModal() to prevent main thread blocking
                panel.begin { response in
                    defer {
                        try? FileManager.default.removeItem(at: tempZip)
                    }
                    guard response == .OK, let destinationURL = panel.url else {
                        completion?(false)
                        return
                    }
                    do {
                        let fm = FileManager.default
                        if fm.fileExists(atPath: destinationURL.path) {
                            try fm.removeItem(at: destinationURL)
                        }
                        try fm.copyItem(at: tempZip, to: destinationURL)
                        BrewLogger.shared.info("Exported logs successfully to \(destinationURL.path)")
                        completion?(true)
                    } catch {
                        BrewLogger.shared.error("Failed to copy exported logs: \(error.localizedDescription)")
                        completion?(false)
                    }
                }
            } catch {
                BrewLogger.shared.error("Export logs failed: \(error.localizedDescription)")
                completion?(false)
            }
        }
    }
}
