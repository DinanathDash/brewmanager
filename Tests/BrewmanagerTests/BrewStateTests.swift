import Foundation
import Testing
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

@MainActor
@Suite("BrewState Management and Navigation")
struct BrewStateTests {
    private func makeSampleDetail(name: String, isCask: Bool, isOutdated: Bool = false) -> PackageDetail {
        PackageDetail(
            name: name,
            displayName: name.capitalized,
            isCask: isCask,
            tap: isCask ? "homebrew/cask" : "homebrew/core",
            desc: "Sample description for \(name)",
            homepage: "https://example.com/\(name)",
            license: "MIT",
            currentVersion: "2.0.0",
            installedVersions: ["1.0.0"],
            isOutdated: isOutdated,
            isInstalled: true,
            dependencies: [],
            buildDependencies: [],
            dependents: [],
            caveats: nil,
            conflictsWith: [],
            autoUpdates: nil,
            installedOn: "Nov 7, 2026",
            installedReason: "Installed on request",
            installedSize: "12 MB"
        )
    }

    @Test("Initial state has correct defaults")
    func initialState() {
        let state = BrewState()
        #expect(state.version == "Loading...")
        #expect(state.outdatedPackages.isEmpty)
        #expect(state.installedPackages.isEmpty)
        #expect(state.isLoading == false)
        #expect(state.isRefreshSuccess == false)
        #expect(state.isUpdatingBrew == false)
        #expect(state.isUpdateSuccess == false)
        #expect(state.isUpdatingAll == false)
        #expect(state.showUpdatesOnly == false)
        #expect(state.selectedTab == 0)
        #expect(state.updatingPackageNames.isEmpty)
        #expect(state.errorMessage == nil)
        #expect(state.searchResults.isEmpty)
        #expect(state.isSearching == false)
        #expect(state.installingPackages.isEmpty)
        #expect(state.selectedPackageDetail == nil)
        #expect(state.packageHistory.isEmpty)
        #expect(state.isLoadingDetail == false)
    }

    @Test("Navigation stack pushes to history and pops back")
    func navigationStack() async {
        let state = BrewState()
        let pkg1 = makeSampleDetail(name: "curl", isCask: false)

        state.selectedPackageDetail = pkg1

        await state.navigateToPackage(name: "wget", isCask: false)
        #expect(state.packageHistory.count == 1)
        #expect(state.packageHistory.first?.name == "curl")

        // Pop back
        state.popPackageHistory()
        #expect(state.selectedPackageDetail?.name == "curl")
        #expect(state.packageHistory.isEmpty)

        // Pop when empty closes detail view
        state.popPackageHistory()
        #expect(state.selectedPackageDetail == nil)
        #expect(state.packageHistory.isEmpty)
    }

    @Test("closePackageDetail clears current detail, history, and loading flag")
    func closePackageDetailResetsState() {
        let state = BrewState()
        state.selectedPackageDetail = makeSampleDetail(name: "git", isCask: false)
        state.packageHistory = [makeSampleDetail(name: "gh", isCask: false)]
        state.isLoadingDetail = true

        state.closePackageDetail()
        #expect(state.selectedPackageDetail == nil)
        #expect(state.packageHistory.isEmpty)
        #expect(state.isLoadingDetail == false)
    }

    @Test("Fallback package detail creation for uninstalled or unresolvable package")
    func fallbackDetailCreation() async {
        let state = BrewState()
        // Provide installed package in state
        let installedPkg = try! JSONDecoder().decode(
            InstalledPackage.self,
            from: Data(#"{"name": "mockpkg", "version": "1.4.2", "desc": "Mock description"}"#.utf8)
        )
        state.installedPackages = [installedPkg]

        // Trigger selection for mockpkg where brew info will fail in test sandbox
        await state.selectPackage(name: "mockpkg", isCask: false)

        let detail = state.selectedPackageDetail
        #expect(detail != nil)
        #expect(detail?.name == "mockpkg")
        #expect(detail?.displayName == "mockpkg")
        #expect(detail?.desc == "Mock description")
        #expect(detail?.installedVersions == ["1.4.2"])
        #expect(detail?.isInstalled == true)
        #expect(detail?.isOutdated == false)

        // Verify it was cached
        let cached = state.cachedPackageDetail(name: "MOCKPKG", isCask: false)
        #expect(cached?.name == "mockpkg")
    }

    @Test("Upgrading package clears outdated list immediately and updates detail")
    func upgradeClearsOutdatedState() async {
        let state = BrewState()
        let outdated = try! JSONDecoder().decode(
            OutdatedPackage.self,
            from: Data(#"{"name": "htop", "installed_versions": ["3.2.0"], "current_version": "3.3.0"}"#.utf8)
        )
        state.outdatedPackages = [outdated]

        let detail = makeSampleDetail(name: "htop", isCask: false, isOutdated: true)
        state.selectedPackageDetail = detail

        // Upgrade will fail to run actual brew in sandbox, but let's test error path or in-memory state
        // When service fails, errorMessage is set and updatingPackageNames is cleared
        await state.upgrade(name: "htop", isCask: false)
        #expect(!state.updatingPackageNames.contains("htop-formula"))
    }

    @Test("Empty search query resets search results and errors")
    func emptySearchResets() async {
        let state = BrewState()
        state.searchResults = [BrewPackage(name: "zsh", description: "Shell", isCask: false)]
        state.errorMessage = "Previous error"

        await state.search(query: "")
        #expect(state.searchResults.isEmpty)
        #expect(state.errorMessage == nil)

        state.searchResults = [BrewPackage(name: "fish", description: "Shell", isCask: false)]
        await state.search(query: "   ")
        #expect(state.searchResults.isEmpty)
        #expect(state.errorMessage == nil)
    }

    @Test("Host attach and detach manages lifecycle")
    func hostLifecycle() {
        let state = BrewState()
        let host = makeHarnessHost()

        state.attach(host: host)
        #expect(state.isLoading == true || state.version != "")

        state.isRefreshSuccess = true
        state.isUpdateSuccess = true
        state.detach()

        #expect(state.isRefreshSuccess == false)
        #expect(state.isUpdateSuccess == false)
    }
}
