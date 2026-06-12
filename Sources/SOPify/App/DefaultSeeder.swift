import Foundation
import SwiftData

enum DefaultSeeder {
    static let defaultCategories: [(name: String, icon: String)] = [
        ("生活", "house.fill"),
        ("工作", "briefcase.fill"),
        ("运动", "figure.run"),
        ("心理", "brain.head.profile"),
        ("出行", "car.fill"),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }

        for (index, cat) in defaultCategories.enumerated() {
            let category = Category(name: cat.name, icon: cat.icon, order: index)
            context.insert(category)
        }
        try? context.save()
    }
}
