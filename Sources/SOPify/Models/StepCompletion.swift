import Foundation
import SwiftData

@Model
final class StepCompletion {
    var id: UUID
    var stepId: UUID
    var completedAt: Date
    var feedbackText: String?
    var record: ExecutionRecord?

    init(stepId: UUID, completedAt: Date, feedbackText: String? = nil) {
        self.id = UUID()
        self.stepId = stepId
        self.completedAt = completedAt
        self.feedbackText = feedbackText
    }
}
