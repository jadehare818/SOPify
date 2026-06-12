import SwiftUI
import SwiftData

@main
struct SOPifyApp: App {
    let container: ModelContainer = {
        let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self, BranchOption.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — delete the old store and retry
            let url = config.url
            let related = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in related {
                try? FileManager.default.removeItem(at: file)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to construct ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
