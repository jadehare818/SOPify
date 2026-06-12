import Foundation
import SwiftData
@testable import SOPify

enum InMemoryContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, SOPify.Category.self, BranchOption.self, Trigger.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
