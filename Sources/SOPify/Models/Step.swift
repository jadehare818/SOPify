import Foundation
import SwiftData

@Model
final class Step {
    var id: UUID
    var text: String
    var order: Int
    var nestedSOPId: UUID?
    var sop: SOP?

    var isNested: Bool { nestedSOPId != nil }

    init(text: String, order: Int, nestedSOPId: UUID? = nil) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.nestedSOPId = nestedSOPId
    }
}
