import Foundation
import SwiftData

enum ChainedTriggerHelper {
    static func fireChainedTriggers(for completedSOPId: UUID, context: ModelContext) {
        guard !NotificationService.shared.isPaused else { return }

        let descriptor = FetchDescriptor<Trigger>(predicate: #Predicate {
            $0.kind == "chained" && $0.isEnabled
        })
        guard let triggers = try? context.fetch(descriptor) else { return }

        for trigger in triggers {
            if trigger.predecessorSOPId == completedSOPId,
               let targetSOP = trigger.sop {
                NotificationService.shared.scheduleChainedNotification(
                    sopName: targetSOP.name,
                    sopId: targetSOP.id
                )
            }
        }
    }
}
