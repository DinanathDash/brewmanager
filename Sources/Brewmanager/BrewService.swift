import Foundation
import OSLog
import DroppyKit

public struct BrewPackage: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)-\(isCask ? "cask" : "formula")" }
    public let name: String
    public let description: String?
    public let isCask: Bool
}

public struct OutdatedPackage: Decodable, Identifiable, Hashable, Sendable {
    public var id: String { "\(name)-\(isCask ? "cask" : "formula")" }
    public let name: String
    public let installedVersions: [String]
    public let currentVersion: String
    public var isCask: Bool = false
    
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
    public var id: String { "\(name)-\(isCask ? "cask" : "formula")" }
    public let name: String
    public let installed: [InstalledPackageVersion]?
    public let version: String?
    public let desc: String?
    public var isCask: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case name
        case token
        case installed
        case version
        case desc
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
        self.desc = try? container.decodeIfPresent(String.self, forKey: .desc)
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
        let setting = preferences.value(forKey: "brewExecutablePath", default: "")
        if !setting.isEmpty { return setting }
        let appleSiliconPath = "/opt/homebrew/bin/brew"
        let intelPath = "/usr/local/bin/brew"
        if FileManager.default.fileExists(atPath: appleSiliconPath) { return appleSiliconPath }
        if FileManager.default.fileExists(atPath: intelPath) { return intelPath }
        return appleSiliconPath
    }
    
    public func checkVersion(executable: String) async throws -> String {
        let output = try await runCommand(executable: executable, arguments: ["--version"], timeout: 10)
        return output.components(separatedBy: .newlines).first ?? "Unknown"
    }
    
    public func fetchOutdated(executable: String) async throws -> OutdatedResponse {
        let output = try await runCommand(executable: executable, arguments: ["outdated", "--json"], timeout: 20)
        guard let data = output.data(using: .utf8) else {
            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        return try JSONDecoder().decode(OutdatedResponse.self, from: data)
    }
    
    public func fetchInstalled(executable: String) async throws -> InstalledResponse {
        let output = try await runCommand(executable: executable, arguments: ["info", "--installed", "--json=v2"], timeout: 30)
        guard let data = output.data(using: .utf8) else {
            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        return try JSONDecoder().decode(InstalledResponse.self, from: data)
    }
    
    public func updateBrew(executable: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["update"])
    }
    
    public func upgradeAll(executable: String) async throws {
        _ = try await runCommand(executable: executable, arguments: ["upgrade"])
    }
    
    public func upgradePackage(executable: String, name: String, isCask: Bool) async throws {
        let kind = isCask ? "--cask" : "--formula"
        _ = try await runCommand(executable: executable, arguments: ["upgrade", kind, name])
    }
    
    public func uninstallPackage(executable: String, name: String, isCask: Bool) async throws {
        let kind = isCask ? "--cask" : "--formula"
        _ = try await runCommand(executable: executable, arguments: ["uninstall", kind, name])
    }
    
    public func installPackage(executable: String, name: String, isCask: Bool) async throws {
        let kind = isCask ? "--cask" : "--formula"
        _ = try await runCommand(executable: executable, arguments: ["install", kind, name])
    }
    
    public func searchPackages(executable: String, query: String) async throws -> [BrewPackage] {
        let output = try await runCommand(executable: executable, arguments: ["desc", "--search", query], timeout: 20)
        
        var results: [BrewPackage] = []
        var parsingCasks = false
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("==> Casks") {
                parsingCasks = true
                continue
            } else if trimmed.hasPrefix("==> Formulae") {
                parsingCasks = false
                continue
            } else if trimmed.hasPrefix("==>") {
                continue // Skip other headers
            }
            
            // Expected format: "name: description"
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let name = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let descStart = trimmed.index(after: colonIndex)
                let description = String(trimmed[descStart...]).trimmingCharacters(in: .whitespaces)
                
                results.append(BrewPackage(name: name, description: description, isCask: parsingCasks))
            } else {
                // Sometime search results without description can appear
                results.append(BrewPackage(name: trimmed, description: nil, isCask: parsingCasks))
            }
        }
        return results
    }
    
    private func runCommand(executable: String, arguments: [String], timeout: TimeInterval? = nil) async throws -> String {
        let isReadOnly = timeout != nil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        process.environment = env
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        final class OutputBuffer: @unchecked Sendable {
            var data = Data()
            private let lock = NSLock()
            func append(_ new: Data) { lock.lock(); defer { lock.unlock() }; data.append(new) }
            func string() -> String { lock.lock(); defer { lock.unlock() }; return String(data: data, encoding: .utf8) ?? "" }
        }
        
        final class ProcessState: @unchecked Sendable {
            var didResume = false
            let lock = NSLock()
        }
        
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                let outData = OutputBuffer()
                let errData = OutputBuffer()
                
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if !chunk.isEmpty {
                        outData.append(chunk)
                    } else {
                        handle.readabilityHandler = nil
                    }
                }
                
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if !chunk.isEmpty {
                        errData.append(chunk)
                    } else {
                        handle.readabilityHandler = nil
                    }
                }
                
                let state = ProcessState()
                
                process.terminationHandler = { p in
                    state.lock.lock()
                    defer { state.lock.unlock() }
                    
                    if state.didResume { return }
                    state.didResume = true
                    
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    
                    if p.terminationStatus != 0 {
                        let errorOutput = errData.string()
                        let outOutput = outData.string()
                        let msg = errorOutput.isEmpty ? outOutput : errorOutput
                        continuation.resume(throwing: NSError(domain: "BrewService", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg]))
                    } else {
                        continuation.resume(returning: outData.string())
                    }
                }
                
                do {
                    try process.run()
                } catch {
                    state.lock.lock()
                    defer { state.lock.unlock() }
                    if !state.didResume {
                        state.didResume = true
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                if let timeout = timeout {
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                }
            }
        } onCancel: {
            if isReadOnly && process.isRunning {
                process.terminate()
            }
        }
    }
}
