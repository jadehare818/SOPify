import Foundation
import SwiftData

enum ExportService {

    // MARK: - Full library export

    static func exportAll(context: ModelContext) throws -> Data {
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))
        let allSOPs = try context.fetch(FetchDescriptor<SOP>())
        let topLevelSOPs = allSOPs.filter { !$0.isChild && !$0.isOneShot }

        let envelope = SOPExportEnvelope(
            version: 1,
            exportedAt: .now,
            categories: categories.map { exportCategory($0) },
            sops: topLevelSOPs.map { exportSOP($0, context: context) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    // MARK: - Single SOP export

    static func exportSingle(sop: SOP, context: ModelContext) throws -> Data {
        let envelope = SOPExportEnvelope(
            version: 1,
            exportedAt: .now,
            categories: sop.category.map { [exportCategory($0)] } ?? [],
            sops: [exportSOP(sop, context: context)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    // MARK: - Private helpers

    private static func exportCategory(_ cat: Category) -> CategoryExport {
        CategoryExport(id: cat.id, name: cat.name, icon: cat.icon, order: cat.order)
    }

    private static func exportSOP(_ sop: SOP, context: ModelContext) -> SOPExport {
        let plainSteps = sop.steps
            .filter { !$0.isNested && !$0.isBranch }
            .sorted(by: { $0.order < $1.order })

        let nestedSteps = sop.steps
            .filter { $0.isNested }
            .sorted(by: { $0.order < $1.order })

        let branchSteps = sop.steps
            .filter { $0.isBranch }
            .sorted(by: { $0.order < $1.order })

        var stepExports: [StepExport] = plainSteps.map { step in
            StepExport(id: step.id, text: step.text, order: step.order, nestedSOP: nil)
        }

        stepExports += nestedSteps.map { step in
            let childSOP: SOPExport? = {
                guard let childId = step.nestedSOPId else { return nil }
                let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == childId })
                guard let child = try? context.fetch(descriptor).first else { return nil }
                return exportSOP(child, context: context)
            }()
            return StepExport(id: step.id, text: step.text, order: step.order, nestedSOP: childSOP)
        }

        let branchExports: [BranchPointExport] = branchSteps.map { step in
            let options = step.branchOptions.sorted(by: { $0.order < $1.order }).map { option in
                let targetSOP: SOPExport = {
                    let targetId = option.targetSOPId
                    let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == targetId })
                    guard let child = try? context.fetch(descriptor).first else {
                        return SOPExport(id: targetId, name: option.label, type: "checklist", isOneShot: false, categoryId: nil, createdAt: .now, steps: [], branchPoints: [], triggers: [])
                    }
                    return exportSOP(child, context: context)
                }()
                return BranchOptionExport(id: option.id, label: option.label, order: option.order, targetSOP: targetSOP)
            }
            return BranchPointExport(id: step.id, question: step.branchQuestion ?? step.text, order: step.order, rejoinAfter: step.rejoinAfter, options: options)
        }

        let triggerExports: [TriggerExport] = sop.triggers.map { trigger in
            TriggerExport(
                kind: trigger.kind,
                recurrence: trigger.recurrence,
                hour: trigger.hour,
                minute: trigger.minute,
                weekday: trigger.weekday,
                dayOfMonth: trigger.dayOfMonth,
                predecessorSOPId: trigger.predecessorSOPId,
                isEnabled: trigger.isEnabled
            )
        }

        return SOPExport(
            id: sop.id,
            name: sop.name,
            type: sop.typeRaw,
            isOneShot: sop.isOneShot,
            categoryId: sop.category?.id,
            createdAt: sop.createdAt,
            steps: stepExports,
            branchPoints: branchExports,
            triggers: triggerExports
        )
    }
}
