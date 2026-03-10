import SwiftUI

@main
struct ReDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar is managed by StatusBarController (NSStatusItem).
        // An empty Settings scene is required to satisfy the App protocol.
        Settings {
            EmptyView()
        }
    }
}
