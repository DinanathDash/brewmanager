import SwiftUI
import DroppyKit

struct ExpandedSurfaceView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: ExpandedSurfaceContext
    
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image.brewIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text("Brew Manager")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                
                Picker("", selection: $selectedTab) {
                    Text("Updates (\(state.outdatedPackages.count))").tag(0)
                    Text("Installed (\(state.installedPackages.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Spacer()
                
                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await state.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                }
            }
            .padding(DroppySpacing.md)
            .background(AdaptiveColors.notchSurfaceCardFill)
            
            Divider()
            
            // Content
            ScrollView {
                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                } else if selectedTab == 0 {
                    updatesList
                } else {
                    installedList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var updatesList: some View {
        if state.outdatedPackages.isEmpty {
            Text("All packages are up to date.")
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .padding(.top, DroppySpacing.xl)
        } else {
            VStack(spacing: DroppySpacing.xsm) {
                ForEach(state.outdatedPackages) { pkg in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pkg.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                            Text("\(pkg.installedVersions.first ?? "Unknown") → \(pkg.currentVersion)")
                                .font(.system(size: 12))
                                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                        }
                        Spacer()
                        Button("Update") {
                            Task { await state.upgrade(package: pkg) }
                        }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        .disabled(state.isLoading)
                    }
                    .padding(DroppySpacing.sm)
                    .background(AdaptiveColors.notchSurfaceCardFill, in: RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                }
            }
            .padding(DroppySpacing.md)
            .droppyFlatGlassControls()
        }
    }
    
    @ViewBuilder
    private var installedList: some View {
        if state.installedPackages.isEmpty {
            Text("No installed packages found.")
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .padding(.top, DroppySpacing.xl)
        } else {
            LazyVStack(spacing: DroppySpacing.xsm) {
                ForEach(state.installedPackages) { pkg in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pkg.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                            if let v = pkg.installed?.first?.version ?? pkg.version {
                                Text(v)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            }
                        }
                        Spacer()
                        Button("Delete") {
                            Task { await state.uninstall(package: pkg) }
                        }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        .disabled(state.isLoading)
                    }
                    .padding(DroppySpacing.sm)
                    .background(AdaptiveColors.notchSurfaceCardFill, in: RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                }
            }
            .padding(DroppySpacing.md)
            .droppyFlatGlassControls()
        }
    }
}
