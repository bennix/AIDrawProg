import SwiftUI
import SwiftData

@main
struct AIDrawProgApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        .modelContainer(for: GenerationRecord.self)
    }
}
