import Foundation
import SwiftUI
import Combine
import DroppyKit

@MainActor
public final class BrewState: ObservableObject {
    @Published public var version: String = "Loading..."
    @Published public var outdatedPackages: [OutdatedPackage] = []
    @Published public var installedPackages: [InstalledPackage] = []
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let service = BrewService()
    private var host: DropletHost?
    
    public init() {}
    
    public func attach(host: DropletHost) {
        self.host = host
        Task {
            await refresh()
        }
    }
    
    private var executablePath: String {
        guard let host = host else { return "/opt/homebrew/bin/brew" }
        return service.getExecutablePath(from: host.preferences)
    }
    
    public func refresh() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let v = service.checkVersion(executable: executablePath)
            async let o = service.fetchOutdated(executable: executablePath)
            async let i = service.fetchInstalled(executable: executablePath)
            
            let (fetchedVersion, outdatedRes, installedRes) = try await (v, o, i)
            
            self.version = fetchedVersion
            self.outdatedPackages = outdatedRes.formulae + outdatedRes.casks
            self.installedPackages = installedRes.formulae + installedRes.casks
        } catch {
            self.errorMessage = error.localizedDescription
            self.host?.log.error("BrewState refresh failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    public func updateBrew() async {
        isLoading = true
        do {
            try await service.updateBrew(executable: executablePath)
            await refresh()
        } catch {
            self.errorMessage = "Update failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    public func upgradeAll() async {
        isLoading = true
        do {
            try await service.upgradeAll(executable: executablePath)
            await refresh()
        } catch {
            self.errorMessage = "Upgrade failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    public func upgrade(package: OutdatedPackage) async {
        isLoading = true
        do {
            try await service.upgradePackage(executable: executablePath, name: package.name)
            await refresh()
        } catch {
            self.errorMessage = "Upgrade failed for \(package.name): \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    public func uninstall(package: InstalledPackage) async {
        isLoading = true
        do {
            try await service.uninstallPackage(executable: executablePath, name: package.name)
            await refresh()
        } catch {
            self.errorMessage = "Uninstall failed for \(package.name): \(error.localizedDescription)"
        }
        isLoading = false
    }
}
