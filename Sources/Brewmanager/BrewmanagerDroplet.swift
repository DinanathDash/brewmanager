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
                    preferredPairedWidth: 210
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(ShelfWidgetView(droplet: self, state: state, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}


// MARK: - Settings Pane

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

// MARK: - HUD

extension BrewmanagerDroplet: HUDPresenting {}

