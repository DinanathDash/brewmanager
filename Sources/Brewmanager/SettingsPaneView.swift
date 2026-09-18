import SwiftUI
import DroppyKit

struct SettingsPaneView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: SettingsPaneContext
    
    @State private var packageToDelete: InstalledPackage?
    @State private var searchText = ""
    @State private var showUpdatesOnly = false
    
    var filteredPackages: [InstalledPackage] {
        var pkgs = state.installedPackages
        if showUpdatesOnly {
            pkgs = pkgs.filter { pkg in
                state.outdatedPackages.contains(where: { $0.name == pkg.name })
            }
        }
        if !searchText.isEmpty {
            pkgs = pkgs.filter { pkg in
                pkg.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        return pkgs
    }
    
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
                            HStack(spacing: DroppySpacing.sm) {
                                Button("Update Homebrew") {
                                    Task { await state.updateBrew() }
                                }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                                .disabled(state.isLoading)
                                
                                Button(state.isLoading ? "Refreshing..." : "Refresh Data Now") {
                                    Task { await state.refresh() }
                                }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                                .disabled(state.isLoading)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                    Text("Installed Packages")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                        .padding(.leading, DroppySpacing.sm)
                    
                    if state.isLoading && state.installedPackages.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if state.installedPackages.isEmpty {
                        DropletSettingsCard {
                            HStack {
                                Text(state.errorMessage ?? "No packages found.")
                                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                    .font(.system(size: 11))
                                Spacer()
                            }
                            .padding(DroppySpacing.sm)
                        }
                    } else {
                        DropletSettingsCard {
                            HStack {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                    TextField("Search...", text: $searchText)
                                        .textFieldStyle(.plain)
                                }
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(16)
                                .frame(width: 160)
                                
                                Spacer()
                                
                                if !state.outdatedPackages.isEmpty {
                                    Button {
                                        Task { await state.upgradeAll() }
                                    } label: {
                                        if state.isUpdatingAll {
                                            HStack {
                                                Text("Updating All...")
                                                ProgressView().scaleEffect(0.5)
                                            }
                                        } else {
                                            Text("Update All")
                                        }
                                    }
                                    .buttonStyle(DroppyAccentButtonStyle(size: .small))
                                    .disabled(state.isUpdatingAll)
                                }
                                
                                Button(showUpdatesOnly ? "Show All" : "Updates Available") {
                                    showUpdatesOnly.toggle()
                                }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                            }
                            .padding(DroppySpacing.sm)
                            
                            DropletSettingsDivider()
                            
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    let pkgs = filteredPackages
                                    if pkgs.isEmpty {
                                        VStack(spacing: DroppySpacing.md) {
                                            Spacer()
                                            Image.brewIcon
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .opacity(0.6)
                                            Text(showUpdatesOnly ? "No updates available." : "No packages match your search.")
                                                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                                .font(.system(size: 13, weight: .medium))
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(.vertical, 40)
                                    } else {
                                        ForEach(Array(pkgs.enumerated()), id: \.element.id) { index, pkg in
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
                                                
                                                if state.updatingPackageNames.contains(pkg.name) {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .padding(.trailing, DroppySpacing.sm)
                                                } else {
                                                    // is it outdated?
                                                    if let outdated = state.outdatedPackages.first(where: { $0.name == pkg.name }) {
                                                        Button {
                                                            Task { await state.upgrade(package: outdated) }
                                                        } label: {
                                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                        }
                                                        .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                                        .help("Update")
                                                        .disabled(state.isUpdatingAll)
                                                    }
                                                    
                                                    Button {
                                                        packageToDelete = pkg
                                                    } label: {
                                                        Image(systemName: "trash")
                                                    }
                                                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                                    .help("Delete")
                                                    .disabled(state.isUpdatingAll)
                                                }
                                            }
                                            .padding(DroppySpacing.sm)
                                            
                                            if index < pkgs.count - 1 {
                                                DropletSettingsDivider()
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 300)
                        }
                        .droppyFlatGlassControls()
                    }
                }
            }
            .confirmationDialog(
                "Delete \(packageToDelete?.name ?? "this package")?",
                isPresented: Binding(
                    get: { packageToDelete != nil },
                    set: { if !$0 { packageToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pkg = packageToDelete {
                        Task { await state.uninstall(package: pkg) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    packageToDelete = nil
                }
            } message: {
                Text("This will run brew uninstall and cannot be undone.")
            }
    }
}
