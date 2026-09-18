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
    @Published public var isUpdatingAll: Bool = false
    @Published public var updatingPackageNames: Set<String> = []
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
        isUpdatingAll = true
        do {
            try await service.upgradeAll(executable: executablePath)
            await refresh()
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated all packages",
                isExpanded: true,
                content: {
                    Image.brewIcon.resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Updated all packages")
                }
            ))
        } catch {
            self.errorMessage = "Upgrade failed: \(error.localizedDescription)"
        }
        isUpdatingAll = false
    }
    
    public func upgrade(package: OutdatedPackage) async {
        updatingPackageNames.insert(package.name)
        do {
            try await service.upgradePackage(executable: executablePath, name: package.name)
            await refresh()
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated \(package.name)",
                isExpanded: true,
                content: {
                    Image.brewIcon.resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Updated \(package.name)")
                }
            ))
        } catch {
            self.errorMessage = "Upgrade failed for \(package.name): \(error.localizedDescription)"
        }
        updatingPackageNames.remove(package.name)
    }
    
    public func uninstall(package: InstalledPackage) async {
        updatingPackageNames.insert(package.name)
        do {
            try await service.uninstallPackage(executable: executablePath, name: package.name)
            await refresh()
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Deleted \(package.name)",
                isExpanded: true,
                content: {
                    Image.brewIcon.resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Deleted \(package.name)")
                }
            ))
        } catch {
            self.errorMessage = "Uninstall failed for \(package.name): \(error.localizedDescription)"
        }
        updatingPackageNames.remove(package.name)
    }
}
