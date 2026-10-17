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
    @Published public var isRefreshSuccess: Bool = false
    @Published public var isUpdatingBrew: Bool = false
    @Published public var isUpdateSuccess: Bool = false
    @Published public var isUpdatingAll: Bool = false
    @Published public var showUpdatesOnly: Bool = false
    @Published public var updatingPackageNames: Set<String> = []
    @Published public var errorMessage: String? = nil
    
    // Discover State
    @Published public var searchResults: [BrewPackage] = []
    @Published public var isSearching: Bool = false
    @Published public var installingPackages: Set<String> = []
    
    private let service = BrewService()
    private var host: DropletHost?
    private var activeGeneration = UUID()
    
    public init() {}
    
    public func attach(host: DropletHost) {
        self.host = host
        self.activeGeneration = UUID()
        let gen = self.activeGeneration
        Task {
            await refresh(generation: gen)
        }
    }
    
    public func detach() {
        host = nil
        activeGeneration = UUID()
        clearActivity()
    }
    
    private var executablePath: String {
        guard let host = host else { return "/opt/homebrew/bin/brew" }
        return service.getExecutablePath(from: host.preferences)
    }
    
    private var dismissalTask: Task<Void, Never>?
    
    private func scheduleDismissal() {
        dismissalTask?.cancel()
        dismissalTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self.isRefreshSuccess = false
            self.isUpdateSuccess = false
        }
    }
    
    public func clearActivity() {
        dismissalTask?.cancel()
        isRefreshSuccess = false
        isUpdateSuccess = false
    }
    
    public func refresh(generation: UUID? = nil) async {
        let gen = generation ?? activeGeneration
        isLoading = true
        errorMessage = nil
        
        do {
            async let v = service.checkVersion(executable: executablePath)
            async let o = service.fetchOutdated(executable: executablePath)
            async let i = service.fetchInstalled(executable: executablePath)
            
            let (fetchedVersion, outdatedRes, installedRes) = try await (v, o, i)
            
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.version = fetchedVersion
            self.outdatedPackages = outdatedRes.formulae + outdatedRes.casks.map { var c = $0; c.isCask = true; return c }
            self.installedPackages = installedRes.formulae + installedRes.casks.map { var c = $0; c.isCask = true; return c }
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = error.localizedDescription
            self.host?.log.error("BrewState refresh failed: \(error.localizedDescription)")
        }
        
        isLoading = false
        
        if errorMessage == nil {
            isRefreshSuccess = true
            scheduleDismissal()
        }
    }
    
    public func updateBrew() async {
        let gen = activeGeneration
        isUpdatingBrew = true
        do {
            try await service.updateBrew(executable: executablePath)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Update failed: \(error.localizedDescription)"
        }
        
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isUpdatingBrew = false
        
        if errorMessage == nil {
            isUpdateSuccess = true
            scheduleDismissal()
        }
    }
    
    public func upgradeAll() async {
        let gen = activeGeneration
        isUpdatingAll = true
        do {
            try await service.upgradeAll(executable: executablePath)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated all packages",
                isExpanded: true,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Updated all packages")
                }
            ))
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Upgrade failed: \(error.localizedDescription)"
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isUpdatingAll = false
    }
    
    public func upgrade(package: OutdatedPackage) async {
        let gen = activeGeneration
        updatingPackageNames.insert(package.id)
        do {
            try await service.upgradePackage(executable: executablePath, name: package.name, isCask: package.isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated \(package.name)",
                isExpanded: true,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Updated \(package.name)")
                }
            ))
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Upgrade failed for \(package.name): \(error.localizedDescription)"
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        updatingPackageNames.remove(package.id)
    }
    
    public func uninstall(package: InstalledPackage) async {
        let gen = activeGeneration
        updatingPackageNames.insert(package.id)
        do {
            try await service.uninstallPackage(executable: executablePath, name: package.name, isCask: package.isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Deleted \(package.name)",
                isExpanded: true,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Deleted \(package.name)")
                }
            ))
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Uninstall failed for \(package.name): \(error.localizedDescription)"
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        updatingPackageNames.remove(package.id)
    }
    
    public func search(query: String) async {
        let gen = activeGeneration
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            self.searchResults = []
            self.errorMessage = nil
            return
        }
        
        isSearching = true
        errorMessage = nil
        do {
            let res = try await service.searchPackages(executable: executablePath, query: trimmedQuery)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.searchResults = res
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Search failed: \(error.localizedDescription)"
            self.searchResults = []
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isSearching = false
    }
    
    public func install(package: BrewPackage) async {
        let gen = activeGeneration
        installingPackages.insert(package.id)
        do {
            try await service.installPackage(executable: executablePath, name: package.name, isCask: package.isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Installed \(package.name)",
                isExpanded: true,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Installed \(package.name)")
                }
            ))
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Install failed for \(package.name): \(error.localizedDescription)"
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        installingPackages.remove(package.id)
    }
}
