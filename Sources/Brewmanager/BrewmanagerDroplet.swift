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
                systemImage: "cup.and.saucer.fill",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .fixed(150)
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(ShelfWidgetView(droplet: self, state: state, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}

// MARK: - Expanded Surface

extension BrewmanagerDroplet: ExpandedSurfaceProviding {
    public var expandedSurfaces: [ExpandedSurfaceDescriptor] {
        [
            ExpandedSurfaceDescriptor(
                id: "expanded-surface",
                title: "Brew Manager",
                systemImage: "cup.and.saucer.fill",
                suppresses: [.shelfWidgets, .autoCollapse]
            )
        ]
    }
    
    public func expandedSurfaceSize(_ id: ExpandedSurfaceID, fitting proposal: ExpandedSurfaceSizeProposal) -> CGSize? {
        // We'll take a large size for the list, capped at the maximum allowed
        let height = min(600.0, proposal.maximumSize.height)
        let width = min(500.0, proposal.maximumSize.width)
        return CGSize(width: width, height: height)
    }
    
    public func makeExpandedSurfaceView(_ id: ExpandedSurfaceID, context: ExpandedSurfaceContext) -> AnyView {
        AnyView(ExpandedSurfaceView(droplet: self, state: state, context: context))
    }
    
    public func expandedSurfaceDidDismiss(_ id: ExpandedSurfaceID, presentation: ExpandedSurfacePresentation, reason: ExpandedSurfaceDismissalReason) {
        // Optional handle dismiss
    }
}

// MARK: - Settings Pane

extension BrewmanagerDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(SettingsPaneView(droplet: self, state: state, context: context))
    }
    
    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "Homebrew Executable", keywords: ["brew", "path", "executable"])
        ]
    }
}

// MARK: - HUD

extension BrewmanagerDroplet: HUDPresenting {}

