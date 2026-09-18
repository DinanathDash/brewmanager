import Foundation
import OSLog
import DroppyKit

public struct OutdatedPackage: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let installedVersions: [String]
    public let currentVersion: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}

public struct OutdatedResponse: Codable, Sendable {
    public let formulae: [OutdatedPackage]
    public let casks: [OutdatedPackage]
}

public struct InstalledPackageVersion: Codable, Hashable, Sendable {
    public let version: String
}

public struct InstalledPackage: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let installed: [InstalledPackageVersion]?
    public let version: String?
}

public struct InstalledResponse: Codable, Sendable {
    public let formulae: [InstalledPackage]
    public let casks: [InstalledPackage]
}

@MainActor
public final class BrewService {
    private let logger = Logger(subsystem: "com.brewmanager", category: "BrewService")
    
    public init() {}
    
    public func getExecutablePath(from preferences: any DropletPreferencesService) -> String {
        return preferences.value(forKey: "brewExecutablePath", default: "/opt/homebrew/bin/brew")
    }
    
    public func checkVersion(executable: String) async throws -> String {
        let output = try await runCommand(executable: executable, arguments: ["--version"])
        return output.components(separatedBy: .newlines).first ?? "Unknown"
    }
    
    public func fetchOutdated(executable: String) async throws -> OutdatedResponse {
        let output = try await runCommand(executable: executable, arguments: ["outdated", "--json"])
        let jsonOutput = extractJSON(from: output)
        guard let data = jsonOutput.data(using: .utf8) else {
            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        return try JSONDecoder().decode(OutdatedResponse.self, from: data)
    }
    
    public func fetchInstalled(executable: String) async throws -> InstalledResponse {
        let output = try await runCommand(executable: executable, arguments: ["info", "--installed", "--json=v2"])
        let jsonOutput = extractJSON(from: output)
        guard let data = jsonOutput.data(using: .utf8) else {
            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        return try JSONDecoder().decode(InstalledResponse.self, from: data)
    }
    
    private func extractJSON(from output: String) -> String {
        if let startIndex = output.firstIndex(of: "{") {
            return String(output[startIndex...])
        }
        return output
    }
    
    public func updateBrew(executable: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["update"])
    }
    
    public func upgradeAll(executable: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["upgrade"])
    }
    
    public func upgradePackage(executable: String, name: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["upgrade", name])
    }
    
    public func uninstallPackage(executable: String, name: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["uninstall", name])
    }
    
    private func runCommand(executable: String, arguments: [String]) async throws -> String {
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            
            // Required so brew can find system tools if PATH isn't set nicely in Droppy
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                "HOMEBREW_NO_AUTO_UPDATE": "1"
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                throw NSError(domain: "BrewService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
            }
            
            return output
        }.value
    }
}
