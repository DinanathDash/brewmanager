import SwiftUI
import DroppyKit

struct SettingsPaneView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: SettingsPaneContext
    
    @State private var packageToDelete: InstalledPackage?
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0: Installed, 1: Discover
    @State private var discoverSearchText = ""
    
    var filteredPackages: [InstalledPackage] {
        var pkgs = state.installedPackages
        if state.showUpdatesOnly {
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
                                Button(state.isUpdatingBrew ? "Updating..." : (state.isUpdateSuccess ? "Updated!" : "Update Homebrew")) {
                                    Task { await state.updateBrew() }
                                }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                                .disabled(state.isLoading || state.isUpdatingBrew || state.isUpdateSuccess)
                                
                                Button(state.isLoading ? "Refreshing..." : (state.isRefreshSuccess ? "Refreshed!" : "Refresh Data Now")) {
                                    Task { await state.refresh() }
                                }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                                .disabled(state.isLoading || state.isUpdatingBrew || state.isRefreshSuccess)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                    HStack {
                        Text("Packages")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Button(action: { selectedTab = 0 }) {
                                Text("Installed")
                                    .font(.system(size: 12, weight: selectedTab == 0 ? .semibold : .regular))
                                    .foregroundStyle(selectedTab == 0 ? AdaptiveColors.notchSurfacePrimaryText : AdaptiveColors.notchSurfaceSecondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedTab == 0 ? Color.white.opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { selectedTab = 1 }) {
                                Text("Discover")
                                    .font(.system(size: 12, weight: selectedTab == 1 ? .semibold : .regular))
                                    .foregroundStyle(selectedTab == 1 ? AdaptiveColors.notchSurfacePrimaryText : AdaptiveColors.notchSurfaceSecondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedTab == 1 ? Color.white.opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(2)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    .padding(.leading, DroppySpacing.sm)
                    
                    if selectedTab == 0 {
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
                                
                                Button(state.showUpdatesOnly ? "Show All" : "Updates Available") {
                                    state.showUpdatesOnly.toggle()
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
                                            Text(state.showUpdatesOnly ? "No updates available." : "No packages match your search.")
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
                                                    HStack(spacing: 6) {
                                                        Text(pkg.name)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                                                        Text(pkg.isCask ? "Cask" : "Formula")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(pkg.isCask ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                                            .foregroundStyle(pkg.isCask ? Color.purple : Color.blue)
                                                            .cornerRadius(4)
                                                    }
                                                    if let v = pkg.installed?.first?.version ?? pkg.version {
                                                        Text(v)
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                                    }
                                                    if let desc = pkg.desc {
                                                        Text(desc)
                                                            .font(.system(size: 11))
                                                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText.opacity(0.8))
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()
                                                
                                                if state.updatingPackageNames.contains(pkg.name) {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .padding(.trailing, DroppySpacing.sm)
                                                } else {
                                                    if let outdated = state.outdatedPackages.first(where: { $0.name == pkg.name }) {
                                                        Button {
                                                            Task { await state.upgrade(package: outdated) }
                                                        } label: {
                                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                                .font(.system(size: 12, weight: .medium))
                                                                .frame(width: 24, height: 24)
                                                                .background(Color.blue.opacity(0.2))
                                                                .foregroundStyle(Color.blue)
                                                                .clipShape(Circle())
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Update")
                                                        .disabled(state.isUpdatingAll)
                                                    }
                                                    
                                                    Button {
                                                        packageToDelete = pkg
                                                    } label: {
                                                        Image(systemName: "trash")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .frame(width: 24, height: 24)
                                                            .background(Color.red.opacity(0.2))
                                                            .foregroundStyle(Color.red)
                                                            .clipShape(Circle())
                                                    }
                                                    .buttonStyle(.plain)
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
                    } // closes else block
                    } else { // closes if selectedTab == 0
                        // Discover Tab
                        DropletSettingsCard {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                    TextField("Search Homebrew...", text: $discoverSearchText)
                                        .textFieldStyle(.plain)
                                        .onSubmit {
                                            Task { await state.search(query: discoverSearchText) }
                                        }
                                }
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(16)
                                
                                Spacer()
                                
                                Button(state.isSearching ? "Searching..." : "Search") {
                                    Task { await state.search(query: discoverSearchText) }
                                }
                                .buttonStyle(DroppyAccentButtonStyle(size: .small))
                                .disabled(state.isSearching || discoverSearchText.isEmpty)
                            }
                            .padding(DroppySpacing.sm)
                            
                            DropletSettingsDivider()
                            
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    let pkgs = state.searchResults
                                    if pkgs.isEmpty {
                                        VStack(spacing: DroppySpacing.md) {
                                            Spacer()
                                            Image.brewIcon
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .opacity(0.6)
                                            Text(discoverSearchText.isEmpty ? "Search for a package to install." : "No packages found.")
                                                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                                .font(.system(size: 13, weight: .medium))
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(.vertical, 40)
                                    } else {
                                        ForEach(Array(pkgs.enumerated()), id: \.element.id) { index, pkg in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 6) {
                                                        Text(pkg.name)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                                                        Text(pkg.isCask ? "Cask" : "Formula")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(pkg.isCask ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                                            .foregroundStyle(pkg.isCask ? Color.purple : Color.blue)
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    if let desc = pkg.description {
                                                        Text(desc)
                                                            .font(.system(size: 11))
                                                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer(minLength: 16)
                                                
                                                if state.installedPackages.contains(where: { $0.name == pkg.name }) {
                                                    Text("Installed")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(Color.green.opacity(0.8))
                                                        .padding(.trailing, DroppySpacing.sm)
                                                } else if state.installingPackages.contains(pkg.name) {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .padding(.trailing, DroppySpacing.sm)
                                                } else {
                                                    Button("Install") {
                                                        Task { await state.install(package: pkg) }
                                                    }
                                                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
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
