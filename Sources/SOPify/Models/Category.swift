import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var order: Int

    @Relationship(deleteRule: .nullify, inverse: \SOP.category)
    var sops: [SOP] = []

    init(name: String, icon: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.order = order
    }
}
