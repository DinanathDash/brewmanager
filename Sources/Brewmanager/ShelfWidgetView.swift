import SwiftUI
import DroppyKit

struct ShelfWidgetView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: ShelfWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            if let wrap = context.notchWrap {
                // Beside the camera: the title in the left band, the control
                // in the right one, nothing in between, in Droppy's own wrapped row.
                ShelfWidgetNotchWrapRow(wrap) {
                    ViewThatFits(in: .horizontal) {
                        headerTitle
                        headerSymbol
                    }
                } trailing: {
                    headerControl
                }
            } else {
                HStack(spacing: DroppySpacing.xsm) {
                    headerTitle
                    Spacer(minLength: 0)
                    if !context.isCompact {
                        headerControl
                    }
                }
            }

            if context.isCompact {
                Spacer(minLength: 0)
                compactBody
            } else {
                soloBody
                Spacer(minLength: 0)
            }
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(!context.isShelfTransitioning)
    }

    private var headerSymbol: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
    }

    private var headerTitle: some View {
        HStack(spacing: DroppySpacing.xsm) {
            headerSymbol
            Text("Brew Manager")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        }
    }

    private var headerControl: some View {
        HStack(spacing: DroppySpacing.xsm) {
            if state.isLoading || state.isUpdatingBrew {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await state.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(
                DroppyWashCircleButtonStyle(
                    diameter: context.washControlSize,
                    tone: .neutral,
                    usesAdaptiveForegrounds: context.usesAdaptiveForegrounds
                )
            )
            .help("Refresh")
            .accessibilityLabel("Refresh")
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.errorMessage != nil {
                Text("Refresh failed")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            } else if state.outdatedPackages.isEmpty {
                Text("All brews updated")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            } else {
                Text("\(state.outdatedPackages.count) updates")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            }
        }
    }

    private var soloBody: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                if state.errorMessage != nil {
                    Text("Error loading data")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                } else if state.outdatedPackages.isEmpty {
                    Text("All brews are updated")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                } else {
                    Text("\(state.outdatedPackages.count) updates available")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                    
                    if let first = state.outdatedPackages.first {
                        HStack(spacing: 4) {
                            Text(first.name)
                                .fontWeight(.medium)
                            Text("(\(first.installedVersionString) → \(first.currentVersion))")
                                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            if state.outdatedPackages.count > 1 {
                                Text("+\(state.outdatedPackages.count - 1) more")
                                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                    }
                }

                Text("Version: \(state.version)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
            }

            Spacer(minLength: DroppySpacing.md)

            if state.isLoading || state.isUpdatingBrew {
                ProgressView().scaleEffect(0.8)
            } else {
                Button("View details") {
                    state.showUpdatesOnly = true
                    if let host = droplet.host {
                        host.workspace.openSettings()
                    }
                }
                .buttonStyle(
                    DroppyWashPillButtonStyle(
                        height: 28,
                        tone: .neutral,
                        usesAdaptiveForegrounds: context.usesAdaptiveForegrounds
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
