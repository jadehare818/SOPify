import Foundation
import SwiftData

enum TriggerKind: String, Codable, CaseIterable {
    case scheduled
    case chained
}

enum TriggerRecurrence: String, Codable, CaseIterable {
    case once
    case daily
    case weekly
    case monthly
}

@Model
final class Trigger {
    var id: UUID
    var kind: String
    var recurrence: String?
    var hour: Int?
    var minute: Int?
    var weekday: Int?
    var dayOfMonth: Int?
    var scheduledDate: Date?
    var predecessorSOPId: UUID?
    var isEnabled: Bool
    var sop: SOP?

    var triggerKind: TriggerKind {
        get { TriggerKind(rawValue: kind) ?? .scheduled }
        set { kind = newValue.rawValue }
    }

    var triggerRecurrence: TriggerRecurrence {
        get { TriggerRecurrence(rawValue: recurrence ?? "once") ?? .once }
        set { recurrence = newValue.rawValue }
    }

    init(kind: TriggerKind, sop: SOP? = nil) {
        self.id = UUID()
        self.kind = kind.rawValue
        self.isEnabled = true
        self.sop = sop
    }
}
