import Foundation
import Testing
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

@MainActor
@Suite("Executable Path and Service Configuration")
struct ExecutablePathTests {
    @Test("getExecutablePath uses user configured preference if present")
    func customPreferencePath() {
        let service = BrewService()
        let host = makeHarnessHost()

        host.preferences.setValue("/my/custom/homebrew/bin/brew", forKey: "brewExecutablePath")
        let path = service.getExecutablePath(from: host.preferences)
        #expect(path == "/my/custom/homebrew/bin/brew")
    }

    @Test("getExecutablePath falls back to standard Homebrew path when preference is empty")
    func defaultPreferencePath() {
        let service = BrewService()
        let host = makeHarnessHost()

        host.preferences.setValue("", forKey: "brewExecutablePath")
        let path = service.getExecutablePath(from: host.preferences)

        let appleSiliconPath = "/opt/homebrew/bin/brew"
        let intelPath = "/usr/local/bin/brew"

        if FileManager.default.fileExists(atPath: appleSiliconPath) {
            #expect(path == appleSiliconPath)
        } else if FileManager.default.fileExists(atPath: intelPath) {
            #expect(path == intelPath)
        } else {
            #expect(path == appleSiliconPath)
        }
    }
}
