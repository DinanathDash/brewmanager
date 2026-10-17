import SwiftUI
import DroppyKit

struct SettingsPaneView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let context: SettingsPaneContext
    
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0: Installed, 1: Discover
    @State private var discoverSearchText = ""
    
    var filteredPackages: [InstalledPackage] {
        var pkgs = state.installedPackages
        if state.showUpdatesOnly {
            pkgs = pkgs.filter { pkg in
                state.outdatedPackages.contains(where: { $0.id == pkg.id })
            }
        }
        if !searchText.isEmpty {
            pkgs = pkgs.filter { pkg in
                let matchesName = pkg.name.localizedCaseInsensitiveContains(searchText)
                let matchesDesc = pkg.desc?.localizedCaseInsensitiveContains(searchText) ?? false
                return matchesName || matchesDesc
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
        DropletSettingsPane {
            DropletSettingsSection(header: { Text("Configuration") }) {
                DropletSettingsCard {
                    DropletControlRow(title: "Homebrew executable") {
                        TextField("", text: brewExecutablePathBinding, prompt: Text("Path"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                    }
                    
                    DropletControlRow(title: "Check for updates") {
                        HStack(spacing: DroppySpacing.sm) {
                            Button(state.isUpdatingBrew ? "Updating..." : (state.isUpdateSuccess ? "Updated" : "Update Homebrew")) {
                                Task { await state.updateBrew() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(state.isLoading || state.isUpdatingBrew || state.isUpdateSuccess)
                            
                            Button(state.isLoading ? "Refreshing..." : (state.isRefreshSuccess ? "Refreshed" : "Refresh data now")) {
                                Task { await state.refresh() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(state.isLoading || state.isUpdatingBrew || state.isRefreshSuccess)
                        }
                    }
                    
                    DropletControlRow(title: "Version") {
                        Text(state.version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
                
            DropletSettingsSection(header: { Text("Packages") }) {
                DropletSettingsCard {
                    DropletControlRow(title: "Mode") {
                        Picker("Mode", selection: $selectedTab) {
                            Text("Installed").tag(0)
                            Text("Discover").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                if selectedTab == 0 {
                    DropletSettingsCard {
                        DropletToggleRow(
                            title: "Show only updates",
                            isOn: $state.showUpdatesOnly
                        )
                        
                        if !state.outdatedPackages.isEmpty {
                            DropletControlRow(title: "Update all") {
                                Button {
                                    Task { await state.upgradeAll() }
                                } label: {
                                    if state.isUpdatingAll {
                                        HStack {
                                            Text("Updating all...")
                                            ProgressView().controlSize(.small)
                                        }
                                    } else {
                                        Text("Update all")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(state.isUpdatingAll)
                            }
                        }
                        
                        SearchField(text: $searchText, placeholder: "Search...")
                            .padding(.vertical, 4)
                    }
                    
                    DropletSettingsCard {
                        if state.isLoading && state.installedPackages.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if state.installedPackages.isEmpty {
                            Text(state.errorMessage ?? "No packages found.")
                                .foregroundStyle(.secondary)
                        } else {
                            let pkgs = filteredPackages
                            if pkgs.isEmpty {
                                Text(state.showUpdatesOnly ? "No updates available." : "No packages match your search.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(pkgs) { pkg in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(pkg.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                Text(pkg.isCask ? "Cask" : "Formula")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let v = pkg.installed?.first?.version ?? pkg.version {
                                                Text(v)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let desc = pkg.desc {
                                                Text(desc)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary.opacity(0.8))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        
                                        if state.updatingPackageNames.contains(pkg.id) {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            if let outdated = state.outdatedPackages.first(where: { $0.id == pkg.id }) {
                                                Button {
                                                    Task { await state.upgrade(package: outdated) }
                                                } label: {
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                }
                                                .buttonStyle(.borderless)
                                                .help("Update")
                                                .disabled(state.isUpdatingAll)
                                            }
                                            
                                            Button {
                                                if DropletConfirmationDialog.present(title: "Delete \(pkg.name)?", message: "This will run brew uninstall and cannot be undone.", confirmTitle: "Delete", symbol: "trash") {
                                                    Task { await state.uninstall(package: pkg) }
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Delete")
                                            .disabled(state.isUpdatingAll)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                } else {
                    // Discover Tab
                    DropletSettingsCard {
                        HStack {
                            SearchField(text: $discoverSearchText, placeholder: "Search Homebrew...", sendsWholeSearchString: true) {
                                Task { await state.search(query: discoverSearchText) }
                            }
                                
                                Button(state.isSearching ? "Searching..." : "Search") {
                                    Task { await state.search(query: discoverSearchText) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(state.isSearching || discoverSearchText.isEmpty)
                            }
                        }
                    

                    DropletSettingsCard {
                        let pkgs = state.searchResults
                        if pkgs.isEmpty {
                            Text(discoverSearchText.isEmpty ? "Search for a package to install." : "No packages found.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(pkgs) { pkg in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(pkg.name)
                                                .font(.system(size: 14, weight: .medium))
                                            Text(pkg.isCask ? "Cask" : "Formula")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        if let desc = pkg.description {
                                            Text(desc)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 16)
                                    
                                    if state.installedPackages.contains(where: { $0.id == pkg.id }) {
                                        Text("Installed")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.green.opacity(0.8))
                                    } else if state.installingPackages.contains(pkg.id) {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Button("Install") {
                                            Task { await state.install(package: pkg) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var sendsWholeSearchString: Bool = false
    var onSubmit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.onSubmitAction(_:))
        searchField.sendsWholeSearchString = sendsWholeSearchString
        if sendsWholeSearchString {
            searchField.sendsSearchStringImmediately = false
        }
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    @MainActor
    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            if let searchField = obj.object as? NSSearchField {
                text = searchField.stringValue
            }
        }
        
        @objc func onSubmitAction(_ sender: NSSearchField) {
            text = sender.stringValue
            onSubmit?()
        }
    }
}
