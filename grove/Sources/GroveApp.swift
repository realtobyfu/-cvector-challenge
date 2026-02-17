import SwiftUI
import SwiftData

@main
struct GroveApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for:
                Item.self,
                Board.self,
                Tag.self,
                Connection.self,
                Annotation.self,
                Nudge.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 800)

        MenuBarExtra("Grove", systemImage: "leaf") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Window("Quick Capture", id: "quick-capture") {
            QuickCapturePanel()
        }
        .modelContainer(modelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .keyboardShortcut("k", modifiers: [.command, .shift])
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 8) {
            Button {
                openWindow(id: "quick-capture")
            } label: {
                Label("Quick Capture", systemImage: "plus.circle")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            InboxCountView()

            Divider()

            Button("Quit Grove") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }
}

struct InboxCountView: View {
    @Query private var allItems: [Item]

    private var inboxCount: Int {
        allItems.filter { $0.status == .inbox }.count
    }

    var body: some View {
        Label("\(inboxCount) items in Inbox", systemImage: "tray")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
