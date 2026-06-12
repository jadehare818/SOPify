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
    @State private var selectedType: SOPType = .checklist
    @State private var nestedEditTarget: SOP?
    @State private var showingSubSOPNameAlert = false
    @State private var subSOPNameDraft = ""

    init(editing: SOP? = nil, isOneShot: Bool = false) {
        self.editing = editing
        self.isOneShot = editing?.isOneShot ?? isOneShot
        _name = State(initialValue: editing?.name ?? "")
        let texts = editing?.steps
            .sorted(by: { $0.order < $1.order })
            .filter { !$0.isNested }
            .map(\.text)
        _stepTexts = State(initialValue: texts?.isEmpty == false ? texts! : [""])
        _selectedCategory = State(initialValue: editing?.category)
        _selectedType = State(initialValue: editing?.type ?? .checklist)
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

                if editing == nil && !isOneShot {
                    Section("Type") {
                        Picker("Type", selection: $selectedType) {
                            Text("Checklist").tag(SOPType.checklist)
                            Text("Flow").tag(SOPType.flow)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let existing = editing, existing.type == .checklist {
                    Section {
                        Button {
                            selectedType = .flow
                        } label: {
                            Label("Upgrade to Flow", systemImage: "arrow.up.circle")
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

                if let existingSOP = editing {
                    Section("Sub-SOPs") {
                        let nestedSteps = existingSOP.steps
                            .filter { $0.isNested }
                            .sorted(by: { $0.order < $1.order })
                        ForEach(nestedSteps) { step in
                            Button {
                                if let childId = step.nestedSOPId {
                                    nestedEditTarget = fetchChild(id: childId)
                                }
                            } label: {
                                HStack {
                                    Label(step.text, systemImage: "folder.fill")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteNestedSteps(nestedSteps: nestedSteps, at: indexSet)
                        }
                        Button {
                            subSOPNameDraft = ""
                            showingSubSOPNameAlert = true
                        } label: {
                            Label("Add Sub-SOP", systemImage: "folder.badge.plus")
                        }
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
            .sheet(item: $nestedEditTarget) { childSOP in
                SOPEditView(editing: childSOP)
            }
            .alert("New Sub-SOP", isPresented: $showingSubSOPNameAlert) {
                TextField("Sub-SOP name", text: $subSOPNameDraft)
                Button("Create") {
                    addNestedSOP(name: subSOPNameDraft)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the sub-SOP.")
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
            existing.typeRaw = selectedType.rawValue

            // Preserve nested steps, only delete plain text steps
            let nestedSteps = existing.steps.filter { $0.isNested }
            let plainSteps = existing.steps.filter { !$0.isNested }
            for step in plainSteps {
                context.delete(step)
            }

            // Recreate plain text steps
            let newPlainSteps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }

            // Re-order nested steps after plain steps
            let baseOrder = newPlainSteps.count
            for (i, nested) in nestedSteps.enumerated() {
                nested.order = baseOrder + i
            }

            existing.steps = newPlainSteps + nestedSteps
        } else {
            let sop = SOP(name: trimmedName, type: selectedType, isOneShot: isOneShot)
            sop.category = selectedCategory
            sop.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
            context.insert(sop)
        }
        try? context.save()
        dismiss()
    }

    private func addNestedSOP(name: String) {
        guard let parent = editing else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Create child SOP
        let childSOP = SOP(name: trimmed, type: .checklist)

        // Create a step pointing to the child
        let stepOrder = parent.steps.count
        let step = Step(text: trimmed, order: stepOrder, nestedSOPId: childSOP.id)

        // Link child back to the step
        childSOP.parentStepId = step.id

        context.insert(childSOP)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()

        // Open the child for editing
        nestedEditTarget = childSOP
    }

    private func deleteNestedSteps(nestedSteps: [Step], at indexSet: IndexSet) {
        guard let parent = editing else { return }
        for index in indexSet {
            let step = nestedSteps[index]
            // Delete the child SOP if it exists
            if let childId = step.nestedSOPId, let child = fetchChild(id: childId) {
                context.delete(child)
            }
            parent.steps.removeAll { $0.id == step.id }
            context.delete(step)
        }
        try? context.save()
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
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
