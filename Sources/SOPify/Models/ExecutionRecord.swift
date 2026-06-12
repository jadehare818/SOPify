import Foundation
import SwiftData

@Model
final class ExecutionRecord {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var sop: SOP?

    @Relationship(deleteRule: .cascade, inverse: \StepCompletion.record)
    var completions: [StepCompletion] = []

    init(sop: SOP, startedAt: Date) {
        self.id = UUID()
        self.sop = sop
        self.startedAt = startedAt
    }
}
