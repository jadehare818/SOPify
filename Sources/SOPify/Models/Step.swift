import Foundation
import SwiftData

@Model
final class Step {
    var id: UUID
    var text: String
    var order: Int
    var nestedSOPId: UUID?
    var branchQuestion: String?
    var rejoinAfter: Bool
    var sop: SOP?

    @Relationship(deleteRule: .cascade, inverse: \BranchOption.step)
    var branchOptions: [BranchOption] = []

    var isNested: Bool { nestedSOPId != nil }
    var isBranch: Bool { branchQuestion != nil }

    init(text: String, order: Int, nestedSOPId: UUID? = nil, branchQuestion: String? = nil, rejoinAfter: Bool = true) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.nestedSOPId = nestedSOPId
        self.branchQuestion = branchQuestion
        self.rejoinAfter = rejoinAfter
    }
}
