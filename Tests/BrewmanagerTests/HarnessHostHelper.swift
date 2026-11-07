import Foundation
import DroppyKit
import DroppyKitHarness
@testable import Brewmanager

/// Helper creating a DropletHost using DroppyKitHarness fake services.
@MainActor
func makeHarnessHost() -> DropletHost {
    let recorder = HarnessRecorder()
    let id = BrewmanagerDroplet.id
    return DropletHost(
        grantedCapabilities: [.hud, .networkClient],
        preferences: HarnessPreferencesService(dropletID: id, recorder: recorder),
        environment: HarnessEnvironmentService(appVersion: "16.0.1", dropletID: id),
        log: HarnessLogService(recorder: recorder),
        installState: HarnessInstallStateService(),
        hud: HarnessHUDService(recorder: recorder),
        shelf: HarnessShelfService(recorder: recorder),
        liveActivity: HarnessLiveActivityService(recorder: recorder),
        notchSurface: HarnessNotchSurfaceService(recorder: recorder, dropletID: id),
        shortcuts: HarnessShortcutsService(recorder: recorder),
        workspace: HarnessWorkspaceService(recorder: recorder),
        feedback: HarnessFeedbackService(recorder: recorder),
        permissions: HarnessPermissionsService(recorder: recorder)
    )
}
