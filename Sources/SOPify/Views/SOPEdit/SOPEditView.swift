import SwiftUI
import SwiftData

struct SOPEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]

    let editing: SOP?
    let isOneShot: Bool

    @State private var name: String = ""
    @State private var stepTexts: [String] = [""]
    @State private var selectedCategory: Category?

    init(editing: SOP? = nil, isOneShot: Bool = false) {
        self.editing = editing
        self.isOneShot = editing?.isOneShot ?? isOneShot
        _name = State(initialValue: editing?.name ?? "")
        let texts = editing?.steps
            .sorted(by: { $0.order < $1.order })
            .map(\.text)
        _stepTexts = State(initialValue: texts?.isEmpty == false ? texts! : [""])
        _selectedCategory = State(initialValue: editing?.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(isOneShot ? "e.g. 明早出门准备" : "e.g. Pack for swim", text: $name)
                }

                if !isOneShot {
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(nil as Category?)
                            ForEach(categories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(cat as Category?)
                            }
                        }
                    }
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
            .navigationTitle(editing == nil ? (isOneShot ? "临时 SOP" : "New SOP") : "Edit SOP")
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
            existing.category = selectedCategory
            for step in existing.steps {
                context.delete(step)
            }
            existing.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
        } else {
            let sop = SOP(name: trimmedName, isOneShot: isOneShot)
            sop.category = selectedCategory
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
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self],
                        inMemory: true)
}

#Preview("Temp") {
    SOPEditView(isOneShot: true)
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self],
                        inMemory: true)
}
