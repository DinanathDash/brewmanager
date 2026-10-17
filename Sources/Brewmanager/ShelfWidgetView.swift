import SwiftUI
import DroppyKit

struct ShelfWidgetView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: ShelfWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(spacing: DroppySpacing.xsm) {
                Image(systemName: "shippingbox.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .padding(.leading, 2)
                Text("Brew Manager")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer(minLength: 0)
                
                if !context.isCompact {
                    Button {
                        Task { await state.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 20))
                    .help("Refresh")
                }
            }
            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

            if context.isCompact {
                if state.errorMessage != nil {
                    Text("Refresh failed")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                } else if state.outdatedPackages.isEmpty {
                    Text("All brews are updated")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                } else {
                    Text("\(state.outdatedPackages.count) updates")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                }
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DroppySpacing.xsm) {
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
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        }
                        
                        Text("Version: \(state.version)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                    
                    Spacer()
                    
                    if state.isLoading || state.isUpdatingBrew {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("View details") {
                            state.showUpdatesOnly = true
                            if let host = droplet.host {
                                host.workspace.openSettings()
                            }
                        }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer(minLength: 0)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
