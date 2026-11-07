import Foundation
import Testing
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

@MainActor
@Suite("Extreme Edge Cases and Stress Tests")
struct ExtremeEdgeCaseTests {

    private func makeQuickDetail(name: String, isCask: Bool = false) -> PackageDetail {
        PackageDetail(
            name: name,
            displayName: name,
            isCask: isCask,
            tap: "homebrew/core",
            desc: "Test description",
            homepage: nil,
            license: nil,
            currentVersion: "1.0",
            installedVersions: ["1.0"],
            isOutdated: false,
            isInstalled: true,
            dependencies: [],
            buildDependencies: [],
            dependents: [],
            caveats: nil,
            conflictsWith: [],
            autoUpdates: nil,
            installedOn: nil,
            installedReason: nil,
            installedSize: nil
        )
    }

    // MARK: - 1. Search Output Extreme Parsing

    @Test("Search output parsing filters ANSI color codes, warnings, and errors")
    func searchOutputFiltersAnsiAndWarnings() {
        let rawCLIOutput = """
        \u{001B}[1m\u{001B}[34m==> Formulae\u{001B}[0m
        git: Fast, scalable, distributed revision control system
        Warning: Calling plist_options is deprecated! Use service instead.
        Notice: Homebrew core tap was auto-updated.
        Error: Failed to fetch remote repository for private-tap
        ffmpeg: Play, record: convert, and stream audio and video
        ripgrep:
        bat
        Random non package text line with no colon
        Invalid Package Name With Spaces: This should definitely be ignored
        \u{001B}[1m\u{001B}[34m==> Casks\u{001B}[0m
        visual-studio-code: Code editor redefined and optimized for building modern applications
        Warning: Cask virtualbox has known issues on macOS Sequoia
        docker: Pack, ship and run any application as a lightweight container
        """

        let packages = BrewService.parseSearchOutput(rawCLIOutput)

        // Verify warnings and errors were not parsed as packages
        #expect(!packages.contains(where: { $0.name == "Warning" }))
        #expect(!packages.contains(where: { $0.name == "Error" }))
        #expect(!packages.contains(where: { $0.name == "Notice" }))
        #expect(!packages.contains(where: { $0.name.contains("Invalid Package") }))

        // Verify valid formulae
        let gitPkg = packages.first(where: { $0.name == "git" })
        #expect(gitPkg != nil)
        #expect(gitPkg?.isCask == false)
        #expect(gitPkg?.description == "Fast, scalable, distributed revision control system")

        let ffmpegPkg = packages.first(where: { $0.name == "ffmpeg" })
        #expect(ffmpegPkg != nil)
        #expect(ffmpegPkg?.isCask == false)
        #expect(ffmpegPkg?.description == "Play, record: convert, and stream audio and video")

        let ripgrepPkg = packages.first(where: { $0.name == "ripgrep" })
        #expect(ripgrepPkg != nil)
        #expect(ripgrepPkg?.description == nil)

        let batPkg = packages.first(where: { $0.name == "bat" })
        #expect(batPkg != nil)
        #expect(batPkg?.description == nil)

        // Verify valid casks
        let vscodePkg = packages.first(where: { $0.name == "visual-studio-code" })
        #expect(vscodePkg != nil)
        #expect(vscodePkg?.isCask == true)

        let dockerPkg = packages.first(where: { $0.name == "docker" })
        #expect(dockerPkg != nil)
        #expect(dockerPkg?.isCask == true)
    }

    // MARK: - 2. Concurrent Logger Stress

    @Test("BrewLogger handles high concurrent writes from multiple threads without deadlock")
    func concurrentLoggingStress() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogStress-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = BrewLogger(
            logDirectory: tempDir,
            fileName: "brewmanager.log",
            maxFileSize: 50 * 1024,
            maxBackups: 2
        )

        // Dispatch 40 concurrent async logging tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...40 {
                group.addTask {
                    logger.info("Concurrent stress log item \(i) with emoji 📦🍺 and unicode üñîçødé")
                }
            }
        }

        logger.flush()

        let logFile = tempDir.appendingPathComponent("brewmanager.log")
        #expect(FileManager.default.fileExists(atPath: logFile.path))
        let content = try String(contentsOf: logFile, encoding: .utf8)
        #expect(content.contains("Concurrent stress log item"))
    }

    @Test("BrewLogger rotates properly even when maxBackups is zero")
    func zeroBackupRotation() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BrewLogZeroBackup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extremely small file size with 0 backups
        let logger = BrewLogger(
            logDirectory: tempDir,
            fileName: "brewmanager.log",
            maxFileSize: 60,
            maxBackups: 0
        )

        for i in 1...5 {
            logger.info("Line \(i) padding to force zero backup rotation")
        }
        logger.flush()

        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? []
        #expect(files.contains("brewmanager.log"))
        // No backup files should exist
        #expect(!files.contains("brewmanager.1.log"))
    }

    // MARK: - 3. State Concurrency & Detach Safety

    @Test("Detach while operations are in flight resets all loading and set flags")
    func detachResetsAllStateFlags() {
        let state = BrewState()
        let host = makeHarnessHost()
        state.attach(host: host)

        state.isLoading = true
        state.isUpdatingBrew = true
        state.isUpdatingAll = true
        state.isSearching = true
        state.isLoadingDetail = true
        state.updatingPackageNames.insert("git-formula")
        state.installingPackages.insert("vscode-cask")

        state.detach()

        #expect(state.isLoading == false)
        #expect(state.isUpdatingBrew == false)
        #expect(state.isUpdatingAll == false)
        #expect(state.isSearching == false)
        #expect(state.isLoadingDetail == false)
        #expect(state.updatingPackageNames.isEmpty)
        #expect(state.installingPackages.isEmpty)
    }

    @Test("Rapid navigation prevents duplicate backstack entry and caps history depth")
    func navigationHistoryDuplicateAndCap() async {
        let state = BrewState()

        let detailA = makeQuickDetail(name: "packageA")
        state.setCachedPackageDetail(detailA)

        // 1. Initial selection
        await state.selectPackage(name: "packageA", isCask: false)
        #expect(state.selectedPackageDetail?.name == "packageA")
        #expect(state.packageHistory.isEmpty)

        // 2. Navigating to the same package should NOT push duplicate onto history
        await state.navigateToPackage(name: "packageA", isCask: false)
        #expect(state.packageHistory.isEmpty)

        // 3. Preload 55 distinct packages in cache for instant navigation without CLI subprocesses
        for i in 1...55 {
            let pkg = makeQuickDetail(name: "package-\(i)")
            state.setCachedPackageDetail(pkg)
            await state.navigateToPackage(name: "package-\(i)", isCask: false)
        }
        #expect(state.packageHistory.count <= 50)
    }

    @Test("Cache key normalizes casing and whitespace")
    func cacheKeyNormalization() async {
        let state = BrewState()

        let detail = makeQuickDetail(name: "htop")
        state.setCachedPackageDetail(detail)

        let cached = state.cachedPackageDetail(name: "  HTOP  ", isCask: false)
        #expect(cached != nil)
        #expect(cached?.name == "htop")

        // Differentiates cask vs formula with identical name
        let caskCached = state.cachedPackageDetail(name: "  HTOP  ", isCask: true)
        #expect(caskCached == nil)
    }

    // MARK: - 4. Settings Route Disambiguation

    @Test("Settings subpage route disambiguates prefix from real formula names")
    func routeDisambiguation() {
        let droplet = BrewmanagerDroplet()
        let state = droplet.state
        let host = makeHarnessHost()
        try? droplet.activate(host: host)

        // Register formula named 'cask-repair'
        let formulaJSON = """
        {"name": "cask-repair", "version": "1.0.0", "desc": "Repair cask taps"}
        """
        let caskRepairFormula = try! JSONDecoder().decode(InstalledPackage.self, from: Data(formulaJSON.utf8))
        state.installedPackages = [caskRepairFormula]

        let context = SettingsPaneContext(presentation: .harness, preferredContentWidth: 420)

        // Opening 'cask-repair' should NOT strip 'cask-' and treat as formula
        let page = droplet.makeSettingsPage(id: "cask-repair", context: context)
        #expect(page != nil)

        // Case-insensitive prefix handling
        let upperCask = droplet.makeSettingsPage(id: "CASK:firefox", context: context)
        #expect(upperCask != nil)

        let upperFormula = droplet.makeSettingsPage(id: "FORMULA:curl", context: context)
        #expect(upperFormula != nil)

        droplet.deactivate()
    }

    // MARK: - 5. Model Extreme Decoding

    @Test("Decodes complex semver and commit-hash versions without failing")
    func complexVersionDecoding() throws {
        let json = """
        {
            "name": "neovim",
            "installed_versions": ["0.10.0-dev-1234+g5b4c3d2"],
            "current_version": "0.10.2_1"
        }
        """
        let pkg = try JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        #expect(pkg.name == "neovim")
        #expect(pkg.installedVersionString == "0.10.0-dev-1234+g5b4c3d2")
        #expect(pkg.currentVersion == "0.10.2_1")
        #expect(pkg.versionTransition == "0.10.0-dev-1234+g5b4c3d2 → 0.10.2_1")
    }

    @Test("Decodes cask info with empty names array and negative/zero timestamp safely")
    func caskInfoExtremeFields() throws {
        let json = """
        {
            "formulae": [],
            "casks": [
                {
                    "token": "edge-cask",
                    "full_token": "homebrew/cask/edge-cask",
                    "tap": "homebrew/cask",
                    "name": [],
                    "desc": "Testing edge cases",
                    "version": "1.0",
                    "installed": "1.0",
                    "installed_time": 0,
                    "outdated": false,
                    "auto_updates": null
                }
            ]
        }
        """
        let res = try JSONDecoder().decode(BrewInfoResponse.self, from: Data(json.utf8))
        #expect(res.casks.count == 1)
        #expect(res.casks[0].token == "edge-cask")
        #expect(res.casks[0].name?.isEmpty == true)
        #expect(res.casks[0].installedTime == 0)
    }
}
