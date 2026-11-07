import AppKit
import Foundation
import Testing
@testable import Brewmanager

@Suite("Diagnostics and Rotating Logger")
struct DiagnosticsTests {
    @Test("BrewLogger records messages at various levels and flushes to disk")
    func loggerRecordsAndFlushes() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = BrewLogger(
            logDirectory: tempDir,
            fileName: "brewmanager.log",
            maxFileSize: 1024 * 1024,
            maxBackups: 3,
            maxAgeDays: 7
        )

        logger.info("Informational message")
        logger.debug("Debug detail")
        logger.notice("Important notice")
        logger.error("Error occurred")
        logger.flush()

        let logFile = tempDir.appendingPathComponent("brewmanager.log")
        #expect(FileManager.default.fileExists(atPath: logFile.path))

        let content = try String(contentsOf: logFile, encoding: .utf8)
        #expect(content.contains("[INFO] Informational message"))
        #expect(content.contains("[DEBUG] Debug detail"))
        #expect(content.contains("[NOTICE] Important notice"))
        #expect(content.contains("[ERROR] Error occurred"))
    }

    @Test("BrewLogger rotates files when size limit is reached")
    func loggerRotatesWhenFull() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogRotateTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Set small file size (150 bytes)
        let logger = BrewLogger(
            logDirectory: tempDir,
            fileName: "brewmanager.log",
            maxFileSize: 150,
            maxBackups: 2,
            maxAgeDays: 7
        )

        for i in 1...10 {
            logger.info("Log line number \(i) with padding to exceed rotation size limit")
        }
        logger.flush()

        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? []
        #expect(files.contains("brewmanager.log"))
        #expect(files.contains("brewmanager.1.log"))
    }

    @Test("BrewLogger purgeAll removes existing logs and starts fresh")
    func loggerPurgeAll() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogPurgeTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = BrewLogger(
            logDirectory: tempDir,
            fileName: "brewmanager.log"
        )

        logger.info("Pre-purge message")
        logger.flush()

        logger.purgeAll()

        logger.info("Post-purge message")
        logger.flush()

        let logFile = tempDir.appendingPathComponent("brewmanager.log")
        let content = try String(contentsOf: logFile, encoding: .utf8)
        #expect(!content.contains("Pre-purge message"))
        #expect(content.contains("Post-purge message"))
    }

    @MainActor
    @Test("BrewLogExporter creates zip archive from log files")
    func exportLogsCreatesZip() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogExportTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let testLog = tempDir.appendingPathComponent("brewmanager.log")
        try "2026-11-07 12:00:00.000 [INFO] Sample diagnostic log\n".write(to: testLog, atomically: true, encoding: .utf8)

        let archiveURL = try await BrewLogExporter.exportLogs(from: tempDir)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        #expect(archiveURL.pathExtension == "zip")

        let attrs = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        let size = (attrs[.size] as? UInt64) ?? 0
        #expect(size > 0)
    }

    @MainActor
    @Test("BrewLogExporter throws error when no log files exist to export")
    func exportLogsEmptyThrows() async {
        let emptyDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogEmptyExportTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        await #expect(throws: Error.self) {
            _ = try await BrewLogExporter.exportLogs(from: emptyDir)
        }
    }
}
