import SwiftUI
import DroppyKit

struct SettingsPaneView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    let context: SettingsPaneContext
    
    var brewExecutablePathBinding: Binding<String> {
        Binding(
            get: { droplet.host?.preferences.value(forKey: "brewExecutablePath", default: "/opt/homebrew/bin/brew") ?? "/opt/homebrew/bin/brew" },
            set: { droplet.host?.preferences.setValue($0, forKey: "brewExecutablePath") }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.lg) {
                
                VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                    Text("Configuration")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                        .padding(.leading, DroppySpacing.sm)
                    
                    DropletSettingsCard {
                        DropletControlRow(title: "Homebrew Executable") {
                            TextField("Path", text: brewExecutablePathBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                        }
                        
                        DropletSettingsDivider()
                        
                        DropletControlRow(title: "Check for Updates") {
                            Button("Refresh Data Now") {
                                Task {
                                    await droplet.state.refresh()
                                }
                            }
                            .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                    HStack {
                        Text("Installed Packages")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            .padding(.leading, DroppySpacing.sm)
                        
                        Spacer()
                        
                        if !droplet.state.outdatedPackages.isEmpty {
                            Button("Update All") {
                                Task { await droplet.state.upgradeAll() }
                            }
                            .buttonStyle(DroppyAccentButtonStyle(size: .small))
                        }
                    }
                    
                    if droplet.state.isLoading {
                        ProgressView().padding()
                    } else if droplet.state.installedPackages.isEmpty {
                        Text("No packages found.")
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DroppySpacing.xsm) {
                                ForEach(droplet.state.installedPackages) { pkg in
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
                                    
                                    // is it outdated?
                                    if let outdated = droplet.state.outdatedPackages.first(where: { $0.name == pkg.name }) {
                                        Button {
                                            Task { await droplet.state.upgrade(package: outdated) }
                                        } label: {
                                            Image(systemName: "arrow.up.circle.fill")
                                        }
                                        .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                        .help("Update")
                                    }
                                    
                                    Button {
                                        Task { await droplet.state.uninstall(package: pkg) }
                                    } label: {
                                        Image(systemName: "trash.fill")
                                    }
                                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                    .help("Delete")
                                }
                                .padding(DroppySpacing.sm)
                                .background(AdaptiveColors.notchSurfaceCardFill, in: RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                            }
                        }
                        .padding(.trailing, DroppySpacing.xs)
                        .frame(height: 300)
                        .droppyFlatGlassControls()
                    }
                }
            }
        }
    }
}
