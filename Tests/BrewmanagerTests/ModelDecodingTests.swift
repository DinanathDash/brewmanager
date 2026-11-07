import Foundation
import Testing
@testable import Brewmanager

@Suite("Model Decoding and Serialization")
struct ModelDecodingTests {
    @Test("BrewPackage id reflects whether package is cask or formula")
    func brewPackageID() {
        let formula = BrewPackage(name: "wget", description: "Internet file retriever", isCask: false)
        #expect(formula.id == "wget-formula")
        #expect(formula.name == "wget")
        #expect(formula.description == "Internet file retriever")
        #expect(formula.isCask == false)

        let cask = BrewPackage(name: "firefox", description: "Web browser", isCask: true)
        #expect(cask.id == "firefox-cask")
        #expect(cask.isCask == true)
    }

    @Test("OutdatedPackage decodes formula with string name")
    func decodeOutdatedFormula() throws {
        let json = """
        {
            "name": "python@3.12",
            "installed_versions": ["3.12.1"],
            "current_version": "3.12.7"
        }
        """
        let pkg = try JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        #expect(pkg.name == "python@3.12")
        #expect(pkg.installedVersions == ["3.12.1"])
        #expect(pkg.currentVersion == "3.12.7")
        #expect(pkg.installedVersionString == "3.12.1")
        #expect(pkg.versionTransition == "3.12.1 → 3.12.7")
        #expect(pkg.id == "python@3.12-formula")
    }

    @Test("OutdatedPackage decodes cask with token field")
    func decodeOutdatedCaskToken() throws {
        let json = """
        {
            "token": "visual-studio-code",
            "installed_versions": ["1.94.0"],
            "current_version": "1.95.0"
        }
        """
        var pkg = try JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        pkg.isCask = true
        #expect(pkg.name == "visual-studio-code")
        #expect(pkg.installedVersions == ["1.94.0"])
        #expect(pkg.currentVersion == "1.95.0")
        #expect(pkg.versionTransition == "1.94.0 → 1.95.0")
        #expect(pkg.id == "visual-studio-code-cask")
    }

    @Test("OutdatedPackage decodes formula with array name format")
    func decodeOutdatedArrayName() throws {
        let json = """
        {
            "name": ["curl"],
            "installed_versions": ["8.9.1"],
            "current_version": "8.10.1"
        }
        """
        let pkg = try JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        #expect(pkg.name == "curl")
        #expect(pkg.installedVersions == ["8.9.1"])
        #expect(pkg.currentVersion == "8.10.1")
    }

    @Test("OutdatedPackage handles empty installed versions gracefully")
    func decodeOutdatedEmptyVersions() throws {
        let json = """
        {
            "name": "ghostscript",
            "installed_versions": [],
            "current_version": "10.04.0"
        }
        """
        let pkg = try JSONDecoder().decode(OutdatedPackage.self, from: Data(json.utf8))
        #expect(pkg.name == "ghostscript")
        #expect(pkg.installedVersionString == "Unknown")
        #expect(pkg.versionTransition == "Unknown → 10.04.0")
    }

    @Test("OutdatedResponse decodes combined formulae and casks JSON")
    func decodeOutdatedResponse() throws {
        let json = """
        {
            "formulae": [
                {
                    "name": "node",
                    "installed_versions": ["22.8.0"],
                    "current_version": "22.11.0"
                }
            ],
            "casks": [
                {
                    "token": "slack",
                    "installed_versions": ["4.39.0"],
                    "current_version": "4.40.0"
                }
            ]
        }
        """
        let response = try JSONDecoder().decode(OutdatedResponse.self, from: Data(json.utf8))
        #expect(response.formulae.count == 1)
        #expect(response.formulae.first?.name == "node")
        #expect(response.casks.count == 1)
        #expect(response.casks.first?.name == "slack")
    }

    @Test("InstalledPackage decodes formula with installed versions array")
    func decodeInstalledFormula() throws {
        let json = """
        {
            "name": "ffmpeg",
            "installed": [
                { "version": "7.0.2" }
            ],
            "version": "7.0.2",
            "desc": "Play, record, convert, and stream audio and video"
        }
        """
        let pkg = try JSONDecoder().decode(InstalledPackage.self, from: Data(json.utf8))
        #expect(pkg.name == "ffmpeg")
        #expect(pkg.installed?.count == 1)
        #expect(pkg.installed?.first?.version == "7.0.2")
        #expect(pkg.version == "7.0.2")
        #expect(pkg.desc == "Play, record, convert, and stream audio and video")
        #expect(pkg.id == "ffmpeg-formula")
    }

    @Test("InstalledPackage decodes cask token")
    func decodeInstalledCask() throws {
        let json = """
        {
            "token": "raycast",
            "version": "1.85.0",
            "desc": "Control your tools with a few keystrokes"
        }
        """
        var pkg = try JSONDecoder().decode(InstalledPackage.self, from: Data(json.utf8))
        pkg.isCask = true
        #expect(pkg.name == "raycast")
        #expect(pkg.version == "1.85.0")
        #expect(pkg.id == "raycast-cask")
    }

    @Test("InstalledResponse decodes combined installed list")
    func decodeInstalledResponse() throws {
        let json = """
        {
            "formulae": [
                { "name": "jq", "installed": [{"version": "1.7.1"}], "version": "1.7.1" }
            ],
            "casks": [
                { "token": "iterm2", "version": "3.5.5" }
            ]
        }
        """
        let response = try JSONDecoder().decode(InstalledResponse.self, from: Data(json.utf8))
        #expect(response.formulae.count == 1)
        #expect(response.formulae.first?.name == "jq")
        #expect(response.casks.count == 1)
        #expect(response.casks.first?.name == "iterm2")
    }

    @Test("BrewInfoResponse decodes v2 JSON with full formula and cask details")
    func decodeBrewInfoResponse() throws {
        let json = """
        {
            "formulae": [
                {
                    "name": "tree",
                    "full_name": "homebrew/core/tree",
                    "tap": "homebrew/core",
                    "desc": "Display directories as trees (with optional color/HTML output)",
                    "license": "GPL-2.0-or-later",
                    "homepage": "http://mama.indstate.edu/users/ice/tree/",
                    "versions": {
                        "stable": "2.1.3",
                        "head": "HEAD"
                    },
                    "dependencies": ["pcre2"],
                    "build_dependencies": [],
                    "conflicts_with": [],
                    "caveats": "Tree caveats note",
                    "keg_only": false,
                    "outdated": false,
                    "deprecated": false,
                    "disabled": false,
                    "installed": [
                        {
                            "version": "2.1.3",
                            "installed_on_request": true,
                            "poured_from_bottle": true,
                            "time": 1730000000
                        }
                    ]
                }
            ],
            "casks": [
                {
                    "token": "1password",
                    "full_token": "homebrew/cask/1password",
                    "tap": "homebrew/cask",
                    "name": ["1Password"],
                    "desc": "Password manager",
                    "homepage": "https://1password.com/",
                    "version": "8.10.50",
                    "installed": "8.10.50",
                    "installed_time": 1730005000,
                    "outdated": false,
                    "auto_updates": true,
                    "caveats": null,
                    "deprecated": false,
                    "disabled": false
                }
            ]
        }
        """
        let info = try JSONDecoder().decode(BrewInfoResponse.self, from: Data(json.utf8))
        #expect(info.formulae.count == 1)
        let formula = info.formulae[0]
        #expect(formula.name == "tree")
        #expect(formula.fullName == "homebrew/core/tree")
        #expect(formula.license == "GPL-2.0-or-later")
        #expect(formula.versions?.stable == "2.1.3")
        #expect(formula.dependencies == ["pcre2"])
        #expect(formula.installed?.first?.installedOnRequest == true)
        #expect(formula.installed?.first?.time == 1730000000)

        #expect(info.casks.count == 1)
        let cask = info.casks[0]
        #expect(cask.token == "1password")
        #expect(cask.name?.first == "1Password")
        #expect(cask.autoUpdates == true)
        #expect(cask.installed == "8.10.50")
    }

    @Test("PackageDetail computed properties and metadata")
    func packageDetailProperties() {
        let detail = PackageDetail(
            name: "git",
            displayName: "Git (VCS)",
            isCask: false,
            tap: "homebrew/core",
            desc: "Fast, scalable, distributed revision control system",
            homepage: "https://git-scm.com",
            license: "GPL-2.0-only",
            currentVersion: "2.47.0",
            installedVersions: ["2.46.0"],
            isOutdated: true,
            isInstalled: true,
            dependencies: ["gettext", "pcre2"],
            buildDependencies: [],
            dependents: ["gh"],
            caveats: "The bash completion has been installed.",
            conflictsWith: [],
            autoUpdates: nil,
            installedOn: "Oct 27, 2026 at 4:33 PM",
            installedReason: "Installed on request",
            installedSize: "45.2 MB"
        )

        #expect(detail.id == "git-formula")
        #expect(detail.displayName == "Git (VCS)")
        #expect(detail.installedVersionString == "2.46.0")
        #expect(detail.versionTransition == "2.46.0 → 2.47.0")
        #expect(detail.isOutdated == true)
        #expect(detail.isInstalled == true)
        #expect(detail.installedReason == "Installed on request")
        #expect(detail.installedSize == "45.2 MB")
        #expect(detail.dependents == ["gh"])
    }

    @Test("PackageDetail when not installed shows None for installedVersionString")
    func packageDetailNotInstalled() {
        let detail = PackageDetail(
            name: "bat",
            displayName: "bat",
            isCask: false,
            tap: "homebrew/core",
            desc: "Clone of cat(1) with syntax highlighting and Git integration",
            homepage: "https://github.com/sharkdp/bat",
            license: "Apache-2.0 or MIT",
            currentVersion: "0.24.0",
            installedVersions: [],
            isOutdated: false,
            isInstalled: false,
            dependencies: ["libgit2", "oniguruma"],
            buildDependencies: [],
            dependents: [],
            caveats: nil,
            conflictsWith: [],
            autoUpdates: nil,
            installedOn: nil,
            installedReason: nil,
            installedSize: nil
        )

        #expect(detail.installedVersionString == "None")
        #expect(detail.versionTransition == "None → 0.24.0")
        #expect(detail.isInstalled == false)
        #expect(detail.isOutdated == false)
    }
}
