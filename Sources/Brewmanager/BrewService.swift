import Foundation
import OSLog
import DroppyKit

public struct OutdatedPackage: Decodable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let installedVersions: [String]
    public let currentVersion: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case token
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let token = try? container.decode(String.self, forKey: .token) {
            self.name = token
        } else if let str = try? container.decode(String.self, forKey: .name) {
            self.name = str
        } else if let arr = try? container.decode([String].self, forKey: .name), let first = arr.first {
            self.name = first
        } else {
            self.name = "Unknown"
        }
        self.installedVersions = (try? container.decode([String].self, forKey: .installedVersions)) ?? []
        self.currentVersion = (try? container.decode(String.self, forKey: .currentVersion)) ?? "Unknown"
    }
}

public struct OutdatedResponse: Decodable, Sendable {
    public let formulae: [OutdatedPackage]
    public let casks: [OutdatedPackage]
}

public struct InstalledPackageVersion: Decodable, Hashable, Sendable {
    public let version: String
}

public struct InstalledPackage: Decodable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let installed: [InstalledPackageVersion]?
    public let version: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case token
        case installed
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let token = try? container.decode(String.self, forKey: .token) {
            self.name = token
        } else if let str = try? container.decode(String.self, forKey: .name) {
            self.name = str
        } else if let arr = try? container.decode([String].self, forKey: .name), let first = arr.first {
            self.name = first
        } else {
            self.name = "Unknown"
        }
        self.installed = try? container.decodeIfPresent([InstalledPackageVersion].self, forKey: .installed)
        self.version = try? container.decodeIfPresent(String.self, forKey: .version)
    }
}

public struct InstalledResponse: Decodable, Sendable {
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
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            process.environment = env
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
                process.waitUntilExit()
                
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus != 0 {
                    throw NSError(domain: "BrewService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
                }
                
                return output
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == 260 {
                    // Sandbox fallback via AppleScript
                    let commandStr = "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin HOMEBREW_NO_AUTO_UPDATE=1 \(executable) \(arguments.joined(separator: " "))"
                    let appleScriptStr = "do shell script \"\(commandStr)\""
                    if let script = NSAppleScript(source: appleScriptStr) {
                        var scriptError: NSDictionary?
                        let result = script.executeAndReturnError(&scriptError)
                        if let err = scriptError {
                            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(err)"])
                        }
                        return result.stringValue ?? ""
                    }
                }
                throw error
            }
        }.value
    }
}
