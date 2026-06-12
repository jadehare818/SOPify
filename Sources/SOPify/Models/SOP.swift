import Foundation
import SwiftData

enum SOPType: String, Codable, CaseIterable {
    case checklist
}

@Model
final class SOP {
    var id: UUID
    var name: String
    var typeRaw: String
    var isOneShot: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.sop)
    var steps: [Step] = []

    var category: Category?

    var type: SOPType {
        get { SOPType(rawValue: typeRaw) ?? .checklist }
        set { typeRaw = newValue.rawValue }
    }

    init(name: String, type: SOPType = .checklist, isOneShot: Bool = false) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.isOneShot = isOneShot
        self.createdAt = .now
        self.updatedAt = .now
    }
}
