import Foundation
import SwiftData

struct ImportResult {
    let categoriesCreated: Int
    let categoriesSkipped: Int
    let sopsCreated: Int
    let sopsSkipped: Int
}

enum ImportService {

    static func importData(_ data: Data, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SOPExportEnvelope.self, from: data)

        var categoriesCreated = 0
        var categoriesSkipped = 0
        var sopsCreated = 0
        var sopsSkipped = 0

        // Import categories
        let existingCategories = try context.fetch(FetchDescriptor<Category>())
        var categoryMap: [UUID: Category] = [:]
        for existing in existingCategories {
            categoryMap[existing.id] = existing
        }

        for catExport in envelope.categories {
            if categoryMap[catExport.id] != nil {
                categoriesSkipped += 1
            } else if existingCategories.contains(where: { $0.name == catExport.name }) {
                // Same name, different ID — skip
                categoriesSkipped += 1
                if let match = existingCategories.first(where: { $0.name == catExport.name }) {
                    categoryMap[catExport.id] = match
                }
            } else {
                let cat = Category(name: catExport.name, icon: catExport.icon, order: catExport.order)
                context.insert(cat)
                categoryMap[catExport.id] = cat
                categoriesCreated += 1
            }
        }

        // Import SOPs
        let existingSOPs = try context.fetch(FetchDescriptor<SOP>())
        let existingSOPIds = Set(existingSOPs.map(\.id))

        for sopExport in envelope.sops {
            if existingSOPIds.contains(sopExport.id) {
                sopsSkipped += 1
            } else {
                importSOP(sopExport, categoryMap: categoryMap, context: context)
                sopsCreated += 1
            }
        }

        try context.save()
        return ImportResult(
            categoriesCreated: categoriesCreated,
            categoriesSkipped: categoriesSkipped,
            sopsCreated: sopsCreated,
            sopsSkipped: sopsSkipped
        )
    }

    // MARK: - Preview (dry run)

    static func preview(_ data: Data) throws -> (categories: Int, sops: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SOPExportEnvelope.self, from: data)
        return (envelope.categories.count, envelope.sops.count)
    }

    // MARK: - Private

    private static func importSOP(_ export: SOPExport, categoryMap: [UUID: Category], context: ModelContext) {
        let sop = SOP(name: export.name, type: SOPType(rawValue: export.type) ?? .checklist, isOneShot: export.isOneShot)
        if let catId = export.categoryId {
            sop.category = categoryMap[catId]
        }

        // Plain + nested steps
        var steps: [Step] = []
        for stepExport in export.steps {
            if let nestedExport = stepExport.nestedSOP {
                let childSOP = createChildSOP(from: nestedExport, categoryMap: categoryMap, context: context)
                let step = Step(text: stepExport.text, order: stepExport.order, nestedSOPId: childSOP.id)
                childSOP.parentStepId = step.id
                steps.append(step)
            } else {
                steps.append(Step(text: stepExport.text, order: stepExport.order))
            }
        }

        // Branch points
        for bpExport in export.branchPoints {
            let step = Step(text: bpExport.question, order: bpExport.order, branchQuestion: bpExport.question, rejoinAfter: bpExport.rejoinAfter)
            for optExport in bpExport.options {
                let childSOP = createChildSOP(from: optExport.targetSOP, categoryMap: categoryMap, context: context)
                childSOP.parentStepId = step.id
                let option = BranchOption(label: optExport.label, order: optExport.order, targetSOPId: childSOP.id)
                option.step = step
                context.insert(option)
            }
            steps.append(step)
        }

        sop.steps = steps

        // Triggers
        for trigExport in export.triggers {
            let trigger = Trigger(kind: TriggerKind(rawValue: trigExport.kind) ?? .scheduled, sop: sop)
            trigger.recurrence = trigExport.recurrence
            trigger.hour = trigExport.hour
            trigger.minute = trigExport.minute
            trigger.weekday = trigExport.weekday
            trigger.dayOfMonth = trigExport.dayOfMonth
            trigger.predecessorSOPId = trigExport.predecessorSOPId
            trigger.isEnabled = trigExport.isEnabled
            context.insert(trigger)
        }

        context.insert(sop)
    }

    private static func createChildSOP(from export: SOPExport, categoryMap: [UUID: Category], context: ModelContext) -> SOP {
        let sop = SOP(name: export.name, type: SOPType(rawValue: export.type) ?? .checklist)
        sop.steps = export.steps.map { Step(text: $0.text, order: $0.order) }
        context.insert(sop)
        return sop
    }
}
