import Foundation
import SwiftData

@Model
final class BranchOption {
    var id: UUID
    var label: String
    var order: Int
    var targetSOPId: UUID?
    var actionText: String?
    var step: Step?

    var isSimpleAction: Bool { targetSOPId == nil }

    init(label: String, order: Int, targetSOPId: UUID? = nil, actionText: String? = nil) {
        self.id = UUID()
        self.label = label
        self.order = order
        self.targetSOPId = targetSOPId
        self.actionText = actionText
    }
}
