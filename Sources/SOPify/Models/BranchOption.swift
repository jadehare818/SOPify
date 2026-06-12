import Foundation
import SwiftData

@Model
final class BranchOption {
    var id: UUID
    var label: String
    var order: Int
    var targetSOPId: UUID
    var step: Step?

    init(label: String, order: Int, targetSOPId: UUID) {
        self.id = UUID()
        self.label = label
        self.order = order
        self.targetSOPId = targetSOPId
    }
}
