import XCTest
import SwiftData
@testable import SOPify

final class StepCompletionTests: XCTestCase {
    func testStepCompletionStoresStepIdAndTimestamp() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let stepId = UUID()
        let now = Date()
        let completion = StepCompletion(stepId: stepId, completedAt: now)
        context.insert(completion)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StepCompletion>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.stepId, stepId)
        XCTAssertEqual(fetched.first?.completedAt, now)
        XCTAssertNil(fetched.first?.feedbackText)
    }

    func testStepCompletionAcceptsFeedbackText() {
        let completion = StepCompletion(stepId: UUID(), completedAt: .now)
        completion.feedbackText = "felt sluggish today"
        XCTAssertEqual(completion.feedbackText, "felt sluggish today")
    }
}
