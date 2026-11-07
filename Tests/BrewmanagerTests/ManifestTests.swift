import Foundation
import Testing
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

@Suite("Manifest and Droplet Descriptors")
struct ManifestTests {
    private func manifestJSON() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("droplet.json")
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func capabilities() throws -> [String] {
        try manifestJSON()["capabilities"] as? [String] ?? []
    }

    private func surfaces() throws -> [String] {
        try manifestJSON()["surfaces"] as? [String] ?? []
    }

    @Test("droplet.json manifest has required droplet identification")
    func manifestIdentity() throws {
        let json = try manifestJSON()
        #expect(json["id"] as? String == "brewmanager")
        #expect(json["name"] as? String == "Brew Manager")
        #expect(json["version"] as? String == "1.1.0")
        #expect(BrewmanagerDroplet.id == "brewmanager")
    }

    @Test("droplet.json specifies minAPI 1.22.0 for notch-wrap and wash controls")
    func requiresMinAPI122() throws {
        let kit = try manifestJSON()["kit"] as? [String: Any]
        #expect(kit?["minAPI"] as? String == "1.22.0")
        #expect(kit?["abi"] as? Int == 1)
    }

    @Test("droplet.json declares expected capabilities and surfaces")
    func manifestCapabilitiesAndSurfaces() throws {
        let caps = try capabilities()
        #expect(caps.contains("hud"))
        #expect(caps.contains("network-client"))

        let surfs = try surfaces()
        #expect(surfs.contains("shelf-widget"))
        #expect(surfs.contains("settings-pane"))
        #expect(surfs.contains("hud"))
    }

    @MainActor
    @Test("BrewmanagerDroplet advertises shelf widget with 136pt fixed height and notch-wrap traits")
    func widgetDescriptorTraits() {
        let droplet = BrewmanagerDroplet()
        let descriptors = droplet.widgetDescriptors
        #expect(descriptors.count == 1)

        guard let widget = descriptors.first else {
            Issue.record("Widget descriptor missing")
            return
        }

        #expect(widget.id == "brewmanager")
        #expect(widget.title == "Brew Manager")
        #expect(widget.systemImage == "shippingbox.fill")
        #expect(widget.layoutTraits.preferredSoloWidth == 420)
        #expect(widget.layoutTraits.preferredPairedWidth == 210)
        #expect(widget.layoutTraits.contentHeight == .fixed(136))

        let notchWrap = widget.layoutTraits.notchWrap
        #expect(notchWrap != nil)
        #expect(notchWrap?.headerHeight == 34)
        #expect(notchWrap?.minimumBandWidth == 64)
    }

    @MainActor
    @Test("BrewmanagerDroplet settings search entries and page provider routing")
    func settingsConfiguration() {
        let droplet = BrewmanagerDroplet()
        let searchEntries = droplet.settingsSearchEntries
        #expect(searchEntries.contains(where: { $0.title == "Homebrew executable" }))

        let host = makeHarnessHost()
        try? droplet.activate(host: host)
        let context = SettingsPaneContext(presentation: .harness, preferredContentWidth: 420)

        // Test different page routing prefixes
        let pageCaskColon = droplet.makeSettingsPage(id: "cask:visual-studio-code", context: context)
        #expect(pageCaskColon != nil)

        let pageCaskDash = droplet.makeSettingsPage(id: "cask-iterm2", context: context)
        #expect(pageCaskDash != nil)

        let pagePackageColon = droplet.makeSettingsPage(id: "package:git", context: context)
        #expect(pagePackageColon != nil)

        let pagePackageDash = droplet.makeSettingsPage(id: "package-ripgrep", context: context)
        #expect(pagePackageDash != nil)

        let pageFormulaColon = droplet.makeSettingsPage(id: "formula:node", context: context)
        #expect(pageFormulaColon != nil)

        let pageFormulaDash = droplet.makeSettingsPage(id: "formula-python", context: context)
        #expect(pageFormulaDash != nil)

        let pageBare = droplet.makeSettingsPage(id: "wget", context: context)
        #expect(pageBare != nil)

        let pageDetailFallback = droplet.makeSettingsPage(id: "package-detail", context: context)
        #expect(pageDetailFallback != nil)

        droplet.deactivate()
    }

    @MainActor
    @Test("BrewmanagerPrincipal instantiates droplet")
    func principalInstantiation() {
        let principal = BrewmanagerPrincipal()
        let dropletObj = principal.makeDroplet()
        #expect(dropletObj is BrewmanagerDroplet)
    }
}
