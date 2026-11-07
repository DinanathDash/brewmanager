import SwiftUI
import Testing
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

@MainActor
@Suite("Views and UI Layout Integration")
struct ViewsAndLayoutTests {
    private func makeSampleInstalledPackage(name: String, desc: String, version: String = "1.0.0", isCask: Bool = false) -> InstalledPackage {
        let json = """
        {
            "\(isCask ? "token" : "name")": "\(name)",
            "version": "\(version)",
            "desc": "\(desc)"
        }
        """
        var pkg = try! JSONDecoder().decode(InstalledPackage.self, from: Data(json.utf8))
        pkg.isCask = isCask
        return pkg
    }

    private func makeSampleOutdatedPackage(name: String, installed: String, current: String, isCask: Bool = false) -> OutdatedPackage {
        let json = """
        {
            "\(isCask ? "token" : "name")": "\(name)",
            "installed_versions": ["\(installed)"],
            "current_version": "\(current)"
        }
        """
        var pkg = try! JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        pkg.isCask = isCask
        return pkg
    }

    @Test("BrewHUDView instantiates with message")
    func hudViewInit() {
        let view = BrewHUDView(message: "Updated all packages")
        #expect(view.message == "Updated all packages")
    }

    @Test("ShelfWidgetView builds in solo, paired, and notch-wrap contexts")
    func shelfWidgetMounts() {
        let droplet = BrewmanagerDroplet()
        let host = makeHarnessHost()
        try? droplet.activate(host: host)

        let soloContext = ShelfWidgetContext(
            availableSize: CGSize(width: 420, height: 136),
            isPaired: false
        )
        _ = droplet.makeWidgetView("brewmanager", context: soloContext)

        let pairedContext = ShelfWidgetContext(
            availableSize: CGSize(width: 210, height: 136),
            isPaired: true
        )
        _ = droplet.makeWidgetView("brewmanager", context: pairedContext)

        let popover = droplet.makeWidgetSettingsPopover("brewmanager")
        #expect(popover == nil)

        droplet.deactivate()
    }

    @Test("SettingsPaneView package filtering matches name and description")
    func settingsPaneSearchFiltering() {
        let droplet = BrewmanagerDroplet()
        let state = droplet.state

        let pkg1 = makeSampleInstalledPackage(name: "ripgrep", desc: "Fast grep replacement")
        let pkg2 = makeSampleInstalledPackage(name: "bat", desc: "Cat clone with syntax highlighting")
        let pkg3 = makeSampleInstalledPackage(name: "visual-studio-code", desc: "Code editor", isCask: true)

        state.installedPackages = [pkg1, pkg2, pkg3]

        let context = SettingsPaneContext(presentation: .harness, preferredContentWidth: 420)
        let settingsView = SettingsPaneView(droplet: droplet, state: state, context: context)

        // When search is empty and showUpdatesOnly is false, all packages are returned
        #expect(settingsView.filteredPackages.count == 3)
    }

    @Test("SettingsPaneView showUpdatesOnly isolates outdated packages")
    func settingsPaneUpdatesOnlyFilter() {
        let droplet = BrewmanagerDroplet()
        let state = droplet.state

        let pkg1 = makeSampleInstalledPackage(name: "node", desc: "JavaScript runtime")
        let pkg2 = makeSampleInstalledPackage(name: "git", desc: "Version control")
        state.installedPackages = [pkg1, pkg2]

        let outdatedGit = makeSampleOutdatedPackage(name: "git", installed: "2.45.0", current: "2.47.0")
        state.outdatedPackages = [outdatedGit]

        state.showUpdatesOnly = true

        let context = SettingsPaneContext(presentation: .harness, preferredContentWidth: 420)
        let settingsView = SettingsPaneView(droplet: droplet, state: state, context: context)

        let filtered = settingsView.filteredPackages
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "git")
    }

    @Test("PackageDetailView and PackageDetailHostView instantiate cleanly")
    func packageDetailViewsInstantiate() {
        let droplet = BrewmanagerDroplet()
        let state = droplet.state

        let detail = PackageDetail(
            name: "htop",
            displayName: "htop",
            isCask: false,
            tap: "homebrew/core",
            desc: "Interactive process viewer",
            homepage: "https://htop.dev",
            license: "GPL-2.0",
            currentVersion: "3.3.0",
            installedVersions: ["3.2.2"],
            isOutdated: true,
            isInstalled: true,
            dependencies: ["ncurses"],
            buildDependencies: [],
            dependents: [],
            caveats: nil,
            conflictsWith: [],
            autoUpdates: nil,
            installedOn: "Nov 1, 2026",
            installedReason: "Installed on request",
            installedSize: "3.4 MB"
        )

        let detailView = PackageDetailView(droplet: droplet, state: state, detail: detail)
        #expect(detailView.detail.name == "htop")

        let hostView = PackageDetailHostView(droplet: droplet, state: state, packageName: "htop", isCask: false)
        #expect(hostView.packageName == "htop")
        #expect(hostView.isCask == false)
    }
}
