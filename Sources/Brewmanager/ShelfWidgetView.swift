import SwiftUI
import DroppyKit

struct ShelfWidgetView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: ShelfWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(spacing: DroppySpacing.xsm) {
                Image.brewIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .padding(.leading, 2)
                Text("Brew Manager")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer(minLength: 0)
                
                if !context.isCompact {
                    Button {
                        if let host = droplet.host {
                            host.workspace.openSettings()
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 20))
                    .help("Settings")
                    
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
                if state.outdatedPackages.isEmpty {
                    Text("All brews are updated")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                } else {
                    Text("\(state.outdatedPackages.count) Updates")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: DroppySpacing.md) {
                    VStack(alignment: .leading, spacing: DroppySpacing.xsm) {
                        if state.errorMessage != nil {
                            Text("Error loading data")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.red)
                        } else if state.outdatedPackages.isEmpty {
                            HStack {
                                Text("All brews are updated")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                                Spacer()
                                if !state.isLoading && !state.isUpdatingBrew {
                                    Button("Update Brew") {
                                        Task { await state.updateBrew() }
                                    }
                                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
                                }
                            }
                        } else {
                            Text("\(state.outdatedPackages.count) updates available")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        }
                        
                        Text("Version: \(state.version)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                    
                    if state.isLoading || state.isUpdatingBrew {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Spacer()
                        }
                    } else if !state.outdatedPackages.isEmpty {
                        HStack(spacing: DroppySpacing.sm) {
                            Button("Update Brew") {
                                Task { await state.updateBrew() }
                            }
                            .buttonStyle(DroppyQuietButtonStyle(size: .small))
                            
                            Button("Update All") {
                                Task { await state.upgradeAll() }
                            }
                            .buttonStyle(DroppyAccentButtonStyle(size: .small))
                            
                            Button("View Details") {
                                state.showUpdatesOnly = true
                                if let host = droplet.host {
                                    host.workspace.openSettings()
                                }
                            }
                            .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
