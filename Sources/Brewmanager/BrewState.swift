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
    @Published public var selectedTab: Int = 0 // 0: Installed, 1: Discover
    @Published public var updatingPackageNames: Set<String> = []
    @Published public var errorMessage: String? = nil
    
    // Discover State
    @Published public var searchResults: [BrewPackage] = []
    @Published public var isSearching: Bool = false
    @Published public var installingPackages: Set<String> = []
    
    // Package Detail State & History
    @Published public var selectedPackageDetail: PackageDetail? = nil
    @Published public var packageHistory: [PackageDetail] = []
    @Published public var isLoadingDetail: Bool = false
    
    // Cache for loaded package details to enable instant back/forward navigation
    private var packageDetailCache: [String: PackageDetail] = [:]
    
    private let service = BrewService()
    private var host: DropletHost?
    private var activeGeneration = UUID()
    
    public init() {}
    
    private func cacheKey(name: String, isCask: Bool) -> String {
        "\(name.lowercased()):\(isCask ? "cask" : "formula")"
    }
    
    public func cachedPackageDetail(name: String, isCask: Bool) -> PackageDetail? {
        packageDetailCache[cacheKey(name: name, isCask: isCask)]
    }
    
    public func attach(host: DropletHost) {
        self.host = host
        self.activeGeneration = UUID()
        let gen = self.activeGeneration
        BrewLogger.shared.info("BrewState attached to host")
        Task {
            await refresh(generation: gen)
        }
    }
    
    public func detach() {
        host = nil
        activeGeneration = UUID()
        clearActivity()
        BrewLogger.shared.info("BrewState detached")
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
            BrewLogger.shared.info("Refresh complete: \(self.outdatedPackages.count) outdated, \(self.installedPackages.count) installed")
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = error.localizedDescription
            self.host?.log.error("BrewState refresh failed: \(error.localizedDescription)")
            BrewLogger.shared.error("Refresh failed: \(error.localizedDescription)")
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
        BrewLogger.shared.info("Updating Homebrew...")
        do {
            try await service.updateBrew(executable: executablePath)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Update failed: \(error.localizedDescription)"
            BrewLogger.shared.error("Homebrew update failed: \(error.localizedDescription)")
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
        BrewLogger.shared.info("Upgrading all packages...")
        do {
            try await service.upgradeAll(executable: executablePath)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.outdatedPackages = []
            await refresh(generation: gen)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated all packages",
                isExpanded: true,
                expandedContentHeight: 44,
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
            BrewLogger.shared.error("Upgrade all failed: \(error.localizedDescription)")
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isUpdatingAll = false
    }
    
    public func selectPackage(name: String, isCask: Bool) async {
        let gen = activeGeneration
        isLoadingDetail = true
        
        // If already cached or current matches, preserve it for instant display
        if let cached = cachedPackageDetail(name: name, isCask: isCask) {
            self.selectedPackageDetail = cached
        } else if selectedPackageDetail?.name.caseInsensitiveCompare(name) != .orderedSame || selectedPackageDetail?.isCask != isCask {
            self.selectedPackageDetail = nil
        }
        
        do {
            let detail = try await service.fetchPackageDetail(executable: executablePath, name: name, isCask: isCask)
            guard gen == activeGeneration, !Task.isCancelled else {
                BrewLogger.shared.info("selectPackage cancelled or generation mismatch for \(name)")
                return
            }
            self.selectedPackageDetail = detail
            self.packageDetailCache[cacheKey(name: name, isCask: isCask)] = detail
            BrewLogger.shared.info("selectPackage successfully loaded detail for \(name)")
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            host?.log.notice("Could not fetch full details for \(name): \(error.localizedDescription)")
            BrewLogger.shared.notice("Could not fetch full details for \(name): \(error.localizedDescription)")
            
            // If fetch fails and no cached detail exists, build best-effort fallback
            if self.selectedPackageDetail == nil {
                let existingInstalled = installedPackages.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask })
                let existingOutdated = outdatedPackages.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask })
                let existingSearch = searchResults.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask })
                
                let installedVer = existingInstalled?.installed?.first?.version ?? existingInstalled?.version
                let currentVer = existingOutdated?.currentVersion ?? (existingInstalled != nil && existingOutdated == nil ? installedVer : nil) ?? "Unknown"
                let fallback = PackageDetail(
                    name: name,
                    displayName: name,
                    isCask: isCask,
                    tap: isCask ? "homebrew/cask" : "homebrew/core",
                    desc: existingInstalled?.desc ?? existingSearch?.description,
                    homepage: nil,
                    license: nil,
                    currentVersion: currentVer,
                    installedVersions: existingInstalled?.installed?.compactMap(\.version) ?? (installedVer != nil ? [installedVer!] : []),
                    isOutdated: existingOutdated != nil,
                    isInstalled: existingInstalled != nil,
                    dependencies: [],
                    buildDependencies: [],
                    dependents: [],
                    caveats: nil,
                    conflictsWith: [],
                    autoUpdates: nil,
                    installedOn: nil,
                    installedReason: nil,
                    installedSize: nil
                )
                self.selectedPackageDetail = fallback
                self.packageDetailCache[cacheKey(name: name, isCask: isCask)] = fallback
            }
        }
        
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isLoadingDetail = false
    }
    
    public func navigateToPackage(name: String, isCask: Bool) async {
        if let current = selectedPackageDetail {
            packageHistory.append(current)
        }
        await selectPackage(name: name, isCask: isCask)
    }
    
    public func popPackageHistory() {
        if !packageHistory.isEmpty {
            selectedPackageDetail = packageHistory.removeLast()
        } else {
            closePackageDetail()
        }
    }
    
    public func closePackageDetail() {
        selectedPackageDetail = nil
        packageHistory = []
        isLoadingDetail = false
    }
    
    public func upgrade(name: String, isCask: Bool) async {
        let gen = activeGeneration
        let pkgId = "\(name)-\(isCask ? "cask" : "formula")"
        updatingPackageNames.insert(pkgId)
        BrewLogger.shared.info("Upgrading package \(name)...")
        do {
            try await service.upgradePackage(executable: executablePath, name: name, isCask: isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            
            // Proactively remove from outdated list so it never persists on return
            self.outdatedPackages.removeAll(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask
            })
            
            // Mark current package detail as updated
            if var current = selectedPackageDetail, current.name.caseInsensitiveCompare(name) == .orderedSame && current.isCask == isCask {
                current = PackageDetail(
                    name: current.name,
                    displayName: current.displayName,
                    isCask: current.isCask,
                    tap: current.tap,
                    desc: current.desc,
                    homepage: current.homepage,
                    license: current.license,
                    currentVersion: current.currentVersion,
                    installedVersions: [current.currentVersion],
                    isOutdated: false,
                    isInstalled: true,
                    dependencies: current.dependencies,
                    buildDependencies: current.buildDependencies,
                    dependents: current.dependents,
                    caveats: current.caveats,
                    conflictsWith: current.conflictsWith,
                    autoUpdates: current.autoUpdates,
                    installedOn: current.installedOn,
                    installedReason: current.installedReason,
                    installedSize: current.installedSize
                )
                self.selectedPackageDetail = current
                self.packageDetailCache[cacheKey(name: name, isCask: isCask)] = current
            }
            
            await refresh(generation: gen)
            if selectedPackageDetail?.name == name && selectedPackageDetail?.isCask == isCask {
                await selectPackage(name: name, isCask: isCask)
            }
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Updated \(name)",
                isExpanded: true,
                expandedContentHeight: 44,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Updated \(name)")
                }
            ))
            BrewLogger.shared.info("Successfully upgraded \(name)")
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Upgrade failed for \(name): \(error.localizedDescription)"
            BrewLogger.shared.error("Upgrade failed for \(name): \(error.localizedDescription)")
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        updatingPackageNames.remove(pkgId)
    }
    
    public func upgrade(package: OutdatedPackage) async {
        await upgrade(name: package.name, isCask: package.isCask)
    }
    
    public func uninstall(name: String, isCask: Bool) async {
        let gen = activeGeneration
        let pkgId = "\(name)-\(isCask ? "cask" : "formula")"
        updatingPackageNames.insert(pkgId)
        BrewLogger.shared.info("Uninstalling package \(name)...")
        do {
            try await service.uninstallPackage(executable: executablePath, name: name, isCask: isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            
            self.installedPackages.removeAll(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask
            })
            self.outdatedPackages.removeAll(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.isCask == isCask
            })
            self.packageDetailCache.removeValue(forKey: cacheKey(name: name, isCask: isCask))
            
            await refresh(generation: gen)
            if selectedPackageDetail?.name == name && selectedPackageDetail?.isCask == isCask {
                await selectPackage(name: name, isCask: isCask)
            }
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Deleted \(name)",
                isExpanded: true,
                expandedContentHeight: 44,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Deleted \(name)")
                }
            ))
            BrewLogger.shared.info("Successfully uninstalled \(name)")
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Uninstall failed for \(name): \(error.localizedDescription)"
            BrewLogger.shared.error("Uninstall failed for \(name): \(error.localizedDescription)")
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        updatingPackageNames.remove(pkgId)
    }
    
    public func uninstall(package: InstalledPackage) async {
        await uninstall(name: package.name, isCask: package.isCask)
    }
    
    public func install(name: String, isCask: Bool) async {
        let gen = activeGeneration
        let pkgId = "\(name)-\(isCask ? "cask" : "formula")"
        installingPackages.insert(pkgId)
        BrewLogger.shared.info("Installing package \(name)...")
        do {
            try await service.installPackage(executable: executablePath, name: name, isCask: isCask)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            await refresh(generation: gen)
            if selectedPackageDetail?.name == name && selectedPackageDetail?.isCask == isCask {
                await selectPackage(name: name, isCask: isCask)
            }
            guard gen == activeGeneration, !Task.isCancelled else { return }
            _ = host?.hud.present(DropletHUDRequest(
                id: "brewmanager-hud",
                accessibilityLabel: "Installed \(name)",
                isExpanded: true,
                expandedContentHeight: 44,
                content: {
                    Image(systemName: "shippingbox.fill").resizable().scaledToFit().frame(width: 16, height: 16)
                },
                expanded: {
                    BrewHUDView(message: "Installed \(name)")
                }
            ))
            BrewLogger.shared.info("Successfully installed \(name)")
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Install failed for \(name): \(error.localizedDescription)"
            BrewLogger.shared.error("Install failed for \(name): \(error.localizedDescription)")
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        installingPackages.remove(pkgId)
    }
    
    public func install(package: BrewPackage) async {
        await install(name: package.name, isCask: package.isCask)
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
        BrewLogger.shared.info("Searching packages: \(trimmedQuery)")
        do {
            let res = try await service.searchPackages(executable: executablePath, query: trimmedQuery)
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.searchResults = res
        } catch {
            guard gen == activeGeneration, !Task.isCancelled else { return }
            self.errorMessage = "Search failed: \(error.localizedDescription)"
            BrewLogger.shared.error("Search failed for \(trimmedQuery): \(error.localizedDescription)")
            self.searchResults = []
        }
        guard gen == activeGeneration, !Task.isCancelled else { return }
        isSearching = false
    }
}
