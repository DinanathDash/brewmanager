import SwiftUI
import AppKit
import DroppyKit

struct PackageDetailHostView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let packageName: String
    let isCask: Bool
    
    private var detail: PackageDetail? {
        if let current = state.selectedPackageDetail, current.name.caseInsensitiveCompare(packageName) == .orderedSame && current.isCask == isCask {
            return current
        }
        return state.cachedPackageDetail(name: packageName, isCask: isCask)
    }
    
    var body: some View {
        DropletSettingsPage {
            if let detail {
                PackageDetailContentView(droplet: droplet, state: state, detail: detail)
            } else {
                DropletSettingsSection(header: { Text("Overview") }) {
                    DropletSettingsCard {
                        VStack(alignment: .leading, spacing: DroppySpacing.md) {
                            HStack {
                                Text(packageName)
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                            Text("Loading package information…")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(detail?.displayName ?? packageName)
        .task(id: "\(packageName):\(isCask)") {
            await state.selectPackage(name: packageName, isCask: isCask)
        }
    }
}

struct PackageDetailView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let detail: PackageDetail
    
    var body: some View {
        DropletSettingsPage {
            PackageDetailContentView(droplet: droplet, state: state, detail: detail)
        }
        .navigationTitle(detail.displayName)
    }
}

struct PackageDetailContentView: View {
    @ObservedObject var droplet: BrewmanagerDroplet
    @ObservedObject var state: BrewState
    let detail: PackageDetail
    
    @Environment(\.dropletSettingsPageOpener) private var opener
    
    private var isUpdating: Bool {
        state.updatingPackageNames.contains(detail.id) || state.installingPackages.contains(detail.id)
    }
    
    private func navigateToPackage(name: String, isCask: Bool) {
        let pageID = isCask ? "cask-\(name)" : "package-\(name)"
        BrewLogger.shared.info("Navigating to dependent/dependency \(name), pageID=\(pageID), openerPresent=\(opener != nil)")
        if let opener {
            opener(page: pageID, title: name)
        } else {
            let opened = droplet.host?.workspace.openSettingsPage(pageID, title: name) ?? false
            if !opened {
                Task { await state.navigateToPackage(name: name, isCask: isCask) }
            }
        }
    }

    var body: some View {
        Group {
            // Harness fallback back button (only shown when opener == nil in isolated harness)
            if opener == nil {
                if !state.packageHistory.isEmpty {
                    HStack {
                        Button {
                            state.popPackageHistory()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(state.packageHistory.last?.displayName ?? "Back")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, DroppySpacing.sm)
                    .padding(.top, DroppySpacing.xs)
                } else {
                    HStack {
                        Button {
                            state.closePackageDetail()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Packages")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, DroppySpacing.sm)
                    .padding(.top, DroppySpacing.xs)
                }
            }
            
            // 1. Overview Card (Reverted to the clean in-card overview)
            DropletSettingsSection(header: { Text("Overview") }) {
                DropletSettingsCard {
                    VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detail.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                
                                HStack(spacing: DroppySpacing.xs) {
                                    Text(detail.isCask ? "Cask" : "Formula")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                    
                                    Text(detail.tap)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Status Badge
                            if detail.isOutdated {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Update Available")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                            } else if detail.isInstalled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Installed")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                            } else {
                                Text("Not Installed")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            }
                        }
                        
                        if let desc = detail.desc, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        // Action Buttons Row (Right-aligned)
                        HStack(spacing: DroppySpacing.sm) {
                            Spacer()
                            
                            if isUpdating {
                                HStack(spacing: DroppySpacing.xsm) {
                                    ProgressView().controlSize(.small)
                                    Text("Processing...")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                if detail.isOutdated {
                                    Button {
                                        Task { await state.upgrade(name: detail.name, isCask: detail.isCask) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Upgrade to \(detail.currentVersion)")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                } else if !detail.isInstalled {
                                    Button {
                                        Task { await state.install(name: detail.name, isCask: detail.isCask) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                            Text("Install")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                                
                                if detail.isInstalled {
                                    Button {
                                        if DropletConfirmationDialog.present(
                                            title: "Delete \(detail.displayName)?",
                                            message: "This will run brew uninstall and cannot be undone.",
                                            confirmTitle: "Delete",
                                            symbol: "trash"
                                        ) {
                                            Task {
                                                await state.uninstall(name: detail.name, isCask: detail.isCask)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                            Text("Uninstall")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 2. Caveats (Immediately after Overview)
            if let caveats = detail.caveats, !caveats.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DropletSettingsSection(header: { Text("Caveats") }) {
                    DropletSettingsCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orange)
                                Text("Important notes")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(caveats)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // 3. Version & Installation Details Card
            DropletSettingsSection(header: { Text("Version & Installation") }) {
                DropletSettingsCard {
                    if detail.isInstalled {
                        DropletControlRow(title: "Installed version") {
                            Text(detail.installedVersionString)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        if let installedOn = detail.installedOn {
                            DropletControlRow(title: "Installed on") {
                                Text(installedOn)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let reason = detail.installedReason {
                            DropletControlRow(title: "Install reason") {
                                Text(reason)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let size = detail.installedSize {
                            DropletControlRow(title: "Installed size") {
                                Text(size)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    DropletControlRow(title: "Latest version") {
                        Text(detail.currentVersion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let autoUpdates = detail.autoUpdates {
                        DropletControlRow(title: "Auto-updates") {
                            Text(autoUpdates ? "Yes" : "No")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // 4. Information Card (Links, License)
            DropletSettingsSection(header: { Text("Information") }) {
                DropletSettingsCard {
                    if let homepage = detail.homepage, let url = URL(string: homepage) {
                        DropletControlRow(title: "Homepage") {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(homepage)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    if let license = detail.license {
                        DropletControlRow(title: "License") {
                            Text(license)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    DropletControlRow(title: "Identifier") {
                        Text(detail.name)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // 5. Dependencies
            if !detail.dependencies.isEmpty || !detail.buildDependencies.isEmpty {
                DropletSettingsSection(header: { Text("Dependencies") }) {
                    DropletSettingsCard {
                        if !detail.dependencies.isEmpty {
                            DropletControlRow(title: "Required") {
                                FlowLayout(spacing: 6) {
                                    ForEach(detail.dependencies, id: \.self) { dep in
                                        Button {
                                            navigateToPackage(name: dep, isCask: false)
                                        } label: {
                                            Text(dep)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .fill(Color.secondary.opacity(0.12))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .help("View \(dep)")
                                    }
                                }
                            }
                        }
                        
                        if !detail.buildDependencies.isEmpty {
                            DropletControlRow(title: "Build only") {
                                FlowLayout(spacing: 6) {
                                    ForEach(detail.buildDependencies, id: \.self) { dep in
                                        Button {
                                            navigateToPackage(name: dep, isCask: false)
                                        } label: {
                                            Text(dep)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .fill(Color.secondary.opacity(0.12))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .help("View \(dep)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 6. Dependents Section (Packages that require this one)
            if !detail.isCask {
                DropletSettingsSection(header: { Text("Dependents") }) {
                    DropletSettingsCard {
                        DropletControlRow(title: "Required by (installed)") {
                            if detail.dependents.isEmpty {
                                Text("No installed packages depend on this formula")
                                    .foregroundStyle(.secondary)
                            } else {
                                FlowLayout(spacing: 6) {
                                    ForEach(detail.dependents, id: \.self) { dep in
                                        Button {
                                            navigateToPackage(name: dep, isCask: false)
                                        } label: {
                                            Text(dep)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .fill(Color.secondary.opacity(0.12))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .help("View \(dep)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 7. Conflicts (if any)
            if !detail.conflictsWith.isEmpty {
                DropletSettingsSection(header: { Text("Conflicts With") }) {
                    DropletSettingsCard {
                        DropletControlRow(title: "Conflicting formulae") {
                            Text(detail.conflictsWith.joined(separator: ", "))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - FlowLayout helper for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
