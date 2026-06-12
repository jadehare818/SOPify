import SwiftUI
import SwiftData

struct SOPEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let editing: SOP?

    @State private var name: String = ""
    @State private var stepTexts: [String] = [""]

    init(editing: SOP? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        let texts = editing?.steps
            .sorted(by: { $0.order < $1.order })
            .map(\.text)
        _stepTexts = State(initialValue: texts?.isEmpty == false ? texts! : [""])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Pack for swim", text: $name)
                }

                Section("Steps") {
                    ForEach(stepTexts.indices, id: \.self) { index in
                        StepEditRow(text: $stepTexts[index]) {
                            stepTexts.remove(at: index)
                            if stepTexts.isEmpty { stepTexts = [""] }
                        }
                    }
                    Button {
                        stepTexts.append("")
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(editing == nil ? "New SOP" : "Edit SOP")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        stepTexts.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let nonEmptySteps = stepTexts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing = editing {
            existing.name = trimmedName
            existing.updatedAt = .now
            for step in existing.steps {
                context.delete(step)
            }
            existing.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
        } else {
            let sop = SOP(name: trimmedName)
            sop.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
            context.insert(sop)
        }
        try? context.save()
        dismiss()
    }
}

#Preview("New") {
    SOPEditView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
}
