import Foundation
import SwiftData

enum SOPType: String, Codable, CaseIterable {
    case checklist
    case flow
    case branching
}

@Model
final class SOP {
    var id: UUID
    var name: String
    var typeRaw: String
    var isOneShot: Bool
    var parentStepId: UUID?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.sop)
    var steps: [Step] = []

    @Relationship(deleteRule: .cascade, inverse: \Trigger.sop)
    var triggers: [Trigger] = []

    var category: Category?

    var type: SOPType {
        get { SOPType(rawValue: typeRaw) ?? .checklist }
        set { typeRaw = newValue.rawValue }
    }

    var isChild: Bool { parentStepId != nil }

    init(name: String, type: SOPType = .checklist, isOneShot: Bool = false) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.isOneShot = isOneShot
        self.createdAt = .now
        self.updatedAt = .now
    }
}
