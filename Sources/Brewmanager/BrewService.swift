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
    
    public var installedVersionString: String {
        installedVersions.first ?? "Unknown"
    }
    
    public var versionTransition: String {
        "\(installedVersionString) → \(currentVersion)"
    }
    
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

// MARK: - Package Details Models

public struct BrewVersions: Decodable, Sendable {
    public let stable: String?
    public let head: String?
}

public struct BrewInstalledVersionInfo: Decodable, Sendable {
    public let version: String?
    public let installedOnRequest: Bool?
    public let pouredFromBottle: Bool?
    public let time: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case installedOnRequest = "installed_on_request"
        case pouredFromBottle = "poured_from_bottle"
        case time
    }
}

public struct BrewFormulaInfo: Decodable, Sendable {
    public let name: String
    public let fullName: String?
    public let tap: String?
    public let desc: String?
    public let license: String?
    public let homepage: String?
    public let versions: BrewVersions?
    public let dependencies: [String]?
    public let buildDependencies: [String]?
    public let conflictsWith: [String]?
    public let caveats: String?
    public let kegOnly: Bool?
    public let outdated: Bool?
    public let deprecated: Bool?
    public let disabled: Bool?
    public let installed: [BrewInstalledVersionInfo]?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap
        case desc
        case license
        case homepage
        case versions
        case dependencies
        case buildDependencies = "build_dependencies"
        case conflictsWith = "conflicts_with"
        case caveats
        case kegOnly = "keg_only"
        case outdated
        case deprecated
        case disabled
        case installed
    }
}

public struct BrewCaskInfo: Decodable, Sendable {
    public let token: String
    public let fullToken: String?
    public let tap: String?
    public let name: [String]?
    public let desc: String?
    public let homepage: String?
    public let version: String?
    public let installed: String?
    public let installedTime: Int?
    public let outdated: Bool?
    public let autoUpdates: Bool?
    public let caveats: String?
    public let deprecated: Bool?
    public let disabled: Bool?

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case tap
        case name
        case desc
        case homepage
        case version
        case installed
        case installedTime = "installed_time"
        case outdated
        case autoUpdates = "auto_updates"
        case caveats
        case deprecated
        case disabled
    }
}

public struct BrewInfoResponse: Decodable, Sendable {
    public let formulae: [BrewFormulaInfo]
    public let casks: [BrewCaskInfo]
}

public struct PackageDetail: Identifiable, Sendable {
    public var id: String { "\(name)-\(isCask ? "cask" : "formula")" }
    public let name: String
    public let displayName: String
    public let isCask: Bool
    public let tap: String
    public let desc: String?
    public let homepage: String?
    public let license: String?
    public let currentVersion: String
    public let installedVersions: [String]
    public let isOutdated: Bool
    public let isInstalled: Bool
    public let dependencies: [String]
    public let buildDependencies: [String]
    public let dependents: [String]
    public let caveats: String?
    public let conflictsWith: [String]
    public let autoUpdates: Bool?
    public let installedOn: String?
    public let installedReason: String?
    public let installedSize: String?
    
    public var installedVersionString: String {
        installedVersions.first ?? "None"
    }
    
    public var versionTransition: String {
        "\(installedVersionString) → \(currentVersion)"
    }
}

@MainActor
public final class BrewService {
    public init() {}
    
    public func getExecutablePath(from preferences: any DropletPreferencesService) -> String {
        let setting = preferences.value(forKey: "brewExecutablePath", default: "").trimmingCharacters(in: .whitespaces)
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
    
    public func fetchPackageDetail(executable: String, name: String, isCask: Bool) async throws -> PackageDetail {
        let args = ["info", isCask ? "--cask" : "--formula", name, "--json=v2"]
        let output: String
        do {
            output = try await runCommand(executable: executable, arguments: args, timeout: 20)
        } catch {
            // Fallback without specifying kind
            output = try await runCommand(executable: executable, arguments: ["info", name, "--json=v2"], timeout: 20)
        }
        
        guard let data = output.data(using: .utf8) else {
            throw NSError(domain: "BrewService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8 from brew info"])
        }
        
        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: data)
        
        // Fetch dependents for formulae (installed packages depending on this one)
        var dependents: [String] = []
        if !isCask {
            if let usesOutput = try? await runCommand(executable: executable, arguments: ["uses", "--installed", name], timeout: 5) {
                dependents = usesOutput
                    .components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("Warning:") && !$0.hasPrefix("Error:") }
            }
        }
        
        // Calculate installed size if installed
        let installedSize = calculateInstalledSize(executable: executable, name: name, isCask: isCask)
        
        if isCask {
            if let cask = response.casks.first(where: { $0.token.caseInsensitiveCompare(name) == .orderedSame }) ?? response.casks.first {
                let installedOnDate: String? = {
                    guard let timestamp = cask.installedTime, timestamp > 0 else { return nil }
                    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    return formatter.string(from: date)
                }()
                
                return PackageDetail(
                    name: cask.token,
                    displayName: cask.name?.first ?? cask.token,
                    isCask: true,
                    tap: cask.tap ?? "homebrew/cask",
                    desc: cask.desc,
                    homepage: cask.homepage,
                    license: nil,
                    currentVersion: cask.version ?? "Unknown",
                    installedVersions: cask.installed != nil ? [cask.installed!] : [],
                    isOutdated: cask.outdated ?? false,
                    isInstalled: cask.installed != nil,
                    dependencies: [],
                    buildDependencies: [],
                    dependents: [],
                    caveats: cask.caveats,
                    conflictsWith: [],
                    autoUpdates: cask.autoUpdates,
                    installedOn: installedOnDate,
                    installedReason: cask.installed != nil ? "Installed via Cask" : nil,
                    installedSize: installedSize
                )
            }
        }
        
        if let formula = response.formulae.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) ?? response.formulae.first {
            let installedList = formula.installed ?? []
            let installedVersions = installedList.compactMap(\.version)
            let isInstalled = !installedVersions.isEmpty
            
            let firstInstalled = installedList.first
            let installedOnDate: String? = {
                guard let timestamp = firstInstalled?.time, timestamp > 0 else { return nil }
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }()
            
            let installedReason: String? = {
                guard isInstalled, let req = firstInstalled?.installedOnRequest else {
                    return isInstalled ? "Installed" : nil
                }
                return req ? "Installed on request" : "Installed as a dependency"
            }()
            
            return PackageDetail(
                name: formula.name,
                displayName: formula.fullName ?? formula.name,
                isCask: false,
                tap: formula.tap ?? "homebrew/core",
                desc: formula.desc,
                homepage: formula.homepage,
                license: formula.license,
                currentVersion: formula.versions?.stable ?? "Unknown",
                installedVersions: installedVersions,
                isOutdated: formula.outdated ?? false,
                isInstalled: isInstalled,
                dependencies: formula.dependencies ?? [],
                buildDependencies: formula.buildDependencies ?? [],
                dependents: dependents,
                caveats: formula.caveats,
                conflictsWith: formula.conflictsWith ?? [],
                autoUpdates: nil,
                installedOn: installedOnDate,
                installedReason: installedReason,
                installedSize: installedSize
            )
        }
        
        // If searching as formula didn't find but cask exists
        if let cask = response.casks.first {
            return PackageDetail(
                name: cask.token,
                displayName: cask.name?.first ?? cask.token,
                isCask: true,
                tap: cask.tap ?? "homebrew/cask",
                desc: cask.desc,
                homepage: cask.homepage,
                license: nil,
                currentVersion: cask.version ?? "Unknown",
                installedVersions: cask.installed != nil ? [cask.installed!] : [],
                isOutdated: cask.outdated ?? false,
                isInstalled: cask.installed != nil,
                dependencies: [],
                buildDependencies: [],
                dependents: [],
                caveats: cask.caveats,
                conflictsWith: [],
                autoUpdates: cask.autoUpdates,
                installedOn: nil,
                installedReason: cask.installed != nil ? "Installed via Cask" : nil,
                installedSize: installedSize
            )
        }
        
        throw NSError(domain: "BrewService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Package details not found for \(name)"])
    }
    
    private func calculateInstalledSize(executable: String, name: String, isCask: Bool) -> String? {
        let basePrefix = executable.replacingOccurrences(of: "/bin/brew", with: "")
        let folderPath: String
        if isCask {
            folderPath = "\(basePrefix)/Caskroom/\(name)"
        } else {
            folderPath = "\(basePrefix)/Cellar/\(name)"
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folderPath) else { return nil }
        
        var totalBytes: Int64 = 0
        let folderURL = URL(fileURLWithPath: folderPath)
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        if let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: Set(keys)), values.isDirectory != true {
                    totalBytes += Int64(values.fileSize ?? 0)
                }
            }
        }
        
        guard totalBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
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
    
    public static func parseSearchOutput(_ output: String) -> [BrewPackage] {
        var results: [BrewPackage] = []
        var parsingCasks = false
        
        // Strip ANSI escape codes
        let ansiRegex = try? NSRegularExpression(pattern: #"\x1b\[[0-9;]*[a-zA-Z]"#)
        let cleanOutput: String
        if let regex = ansiRegex {
            cleanOutput = regex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: ""
            )
        } else {
            cleanOutput = output
        }
        
        for rawLine in cleanOutput.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("==> Casks") {
                parsingCasks = true
                continue
            } else if trimmed.hasPrefix("==> Formulae") {
                parsingCasks = false
                continue
            } else if trimmed.hasPrefix("==>") {
                continue
            }
            
            // Skip CLI warning and error messages
            if trimmed.hasPrefix("Warning:") || trimmed.hasPrefix("Error:") || trimmed.hasPrefix("Notice:") {
                continue
            }
            
            // Expected format: "name: description"
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let name = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let descStart = trimmed.index(after: colonIndex)
                let description = String(trimmed[descStart...]).trimmingCharacters(in: .whitespaces)
                
                // Package names in Homebrew do not contain spaces
                if !name.isEmpty && !name.contains(" ") {
                    results.append(BrewPackage(name: name, description: description.isEmpty ? nil : description, isCask: parsingCasks))
                }
            } else if !trimmed.contains(" ") {
                results.append(BrewPackage(name: trimmed, description: nil, isCask: parsingCasks))
            }
        }
        return results
    }
    
    public func searchPackages(executable: String, query: String) async throws -> [BrewPackage] {
        let output = try await runCommand(executable: executable, arguments: ["desc", "--search", query], timeout: 20)
        return Self.parseSearchOutput(output)
    }
    
    private func runCommand(executable: String, arguments: [String], timeout: TimeInterval? = nil) async throws -> String {
        BrewLogger.shared.info("Executing: \(executable) \(arguments.joined(separator: " "))")
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
            func string() -> String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
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
                    
                    // Drain remaining buffered data from the pipe handles
                    let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingOut.isEmpty { outData.append(remainingOut) }
                    let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingErr.isEmpty { errData.append(remainingErr) }
                    
                    if p.terminationStatus != 0 {
                        let errorOutput = errData.string()
                        let outOutput = outData.string()
                        let msg = errorOutput.isEmpty ? outOutput : errorOutput
                        BrewLogger.shared.error("Command exited with code \(p.terminationStatus): \(msg)")
                        continuation.resume(throwing: NSError(domain: "BrewService", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg]))
                    } else {
                        let result = outData.string()
                        BrewLogger.shared.debug("Command succeeded: \(arguments.first ?? "")")
                        continuation.resume(returning: result)
                    }
                }
                
                do {
                    try process.run()
                } catch {
                    state.lock.lock()
                    defer { state.lock.unlock() }
                    if !state.didResume {
                        state.didResume = true
                        BrewLogger.shared.error("Failed to run process \(executable): \(error.localizedDescription)")
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
