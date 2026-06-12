import Foundation
import SwiftData

@Model
final class Step {
    var id: UUID
    var text: String
    var order: Int
    var sop: SOP?

    init(text: String, order: Int) {
        self.id = UUID()
        self.text = text
        self.order = order
    }
}
