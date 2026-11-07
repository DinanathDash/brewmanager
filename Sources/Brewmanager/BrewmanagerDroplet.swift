//
//  BrewmanagerDroplet.swift
//  Brewmanager
//

import Combine
import DroppyKit
import SwiftUI

/// The class Droppy's loader instantiates, named in the bundle's
/// `NSPrincipalClass`. Keep it empty: it runs before the host is ready.
@objc(BrewmanagerPrincipal)
public final class BrewmanagerPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { BrewmanagerDroplet() }
}

/// Brewmanager.
@MainActor
public final class BrewmanagerDroplet: NSObject, ObservableObject, Droplet {
    /// Must equal `DroppyDropletID` in the bundle's Info.plist and `id` in
    /// droplet.json. The loader refuses the bundle if the three disagree.
    public nonisolated static let id: DropletID = "brewmanager"

    public private(set) var host: DropletHost?
    public let state = BrewState()

    public func activate(host: DropletHost) throws {
        self.host = host
        state.attach(host: host)
        host.log.info("Brewmanager activated")
    }

    public func deactivate() {
        state.detach()
        host = nil
    }
}

// MARK: - Shelf widget

extension BrewmanagerDroplet: ShelfWidgetProviding {
    public var widgetDescriptors: [ShelfWidgetDescriptor] {
        [
            ShelfWidgetDescriptor(
                id: "brewmanager",
                title: "Brew Manager",
                systemImage: "shippingbox.fill",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .fixed(136),
                    // Alone on a Mac with a notch or the camera island, the
                    // header row rises into the bands beside the camera.
                    notchWrap: ShelfWidgetNotchWrapTraits(headerHeight: 34, minimumBandWidth: 64)
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(ShelfWidgetView(droplet: self, state: state, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}

// MARK: - Settings Pane & Pages

extension BrewmanagerDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(SettingsPaneView(droplet: self, state: state, context: context))
    }
    
    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "Homebrew executable", keywords: ["brew", "path", "executable"])
        ]
    }
}

extension BrewmanagerDroplet: SettingsPagesProviding {
    public func makeSettingsPage(id: String, context: SettingsPaneContext) -> AnyView? {
        BrewLogger.shared.info("makeSettingsPage called with id: \(id)")
        let lower = id.lowercased()
        let pkgName: String
        let isCask: Bool
        
        if lower.hasPrefix("cask:") {
            pkgName = String(id.dropFirst("cask:".count)).trimmingCharacters(in: .whitespaces)
            isCask = true
        } else if lower.hasPrefix("package:") {
            pkgName = String(id.dropFirst("package:".count)).trimmingCharacters(in: .whitespaces)
            isCask = false
        } else if lower.hasPrefix("formula:") {
            pkgName = String(id.dropFirst("formula:".count)).trimmingCharacters(in: .whitespaces)
            isCask = false
        } else if lower.hasPrefix("cask-") {
            // Check if exact name exists as formula (e.g. formula 'cask-repair')
            let candidate = String(id.dropFirst("cask-".count)).trimmingCharacters(in: .whitespaces)
            if state.installedPackages.contains(where: { $0.name.caseInsensitiveCompare(id) == .orderedSame && !$0.isCask }) {
                pkgName = id
                isCask = false
            } else {
                pkgName = candidate
                isCask = true
            }
        } else if lower.hasPrefix("package-") {
            pkgName = String(id.dropFirst("package-".count)).trimmingCharacters(in: .whitespaces)
            isCask = false
        } else if lower.hasPrefix("formula-") {
            pkgName = String(id.dropFirst("formula-".count)).trimmingCharacters(in: .whitespaces)
            isCask = false
        } else if id == "package-detail", let current = state.selectedPackageDetail {
            pkgName = current.name
            isCask = current.isCask
        } else {
            pkgName = id.trimmingCharacters(in: .whitespaces)
            isCask = state.installedPackages.first(where: { $0.name.caseInsensitiveCompare(pkgName) == .orderedSame })?.isCask
                ?? state.outdatedPackages.first(where: { $0.name.caseInsensitiveCompare(pkgName) == .orderedSame })?.isCask
                ?? false
        }
        
        return AnyView(PackageDetailHostView(droplet: self, state: state, packageName: pkgName, isCask: isCask))
    }
}

// MARK: - HUD

extension BrewmanagerDroplet: HUDPresenting {}
