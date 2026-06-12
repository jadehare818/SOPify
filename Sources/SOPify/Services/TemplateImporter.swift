import Foundation
import SwiftData

enum TemplateImporter {
    static func importTemplate(_ template: SOPTemplate, categories: [Category], context: ModelContext) -> SOP {
        let sop = SOP(name: template.name, type: template.sopType)
        sop.category = categories.first(where: { $0.name == template.category })

        var steps: [Step] = []
        for (i, stepTemplate) in template.steps.enumerated() {
            if let nestedTemplate = stepTemplate.nested {
                let childSOP = buildSOP(from: nestedTemplate, context: context)
                context.insert(childSOP)

                let step = Step(text: stepTemplate.text, order: i, nestedSOPId: childSOP.id)
                childSOP.parentStepId = step.id
                steps.append(step)
            } else {
                steps.append(Step(text: stepTemplate.text, order: i))
            }
        }
        sop.steps = steps
        return sop
    }

    private static func buildSOP(from template: SOPTemplate, context: ModelContext) -> SOP {
        let sop = SOP(name: template.name, type: template.sopType)

        var steps: [Step] = []
        for (i, stepTemplate) in template.steps.enumerated() {
            if let nestedTemplate = stepTemplate.nested {
                let childSOP = buildSOP(from: nestedTemplate, context: context)
                context.insert(childSOP)

                let step = Step(text: stepTemplate.text, order: i, nestedSOPId: childSOP.id)
                childSOP.parentStepId = step.id
                steps.append(step)
            } else {
                steps.append(Step(text: stepTemplate.text, order: i))
            }
        }
        sop.steps = steps
        return sop
    }
}
