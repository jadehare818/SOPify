import SwiftUI
import SwiftData

@main
struct SOPifyApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
