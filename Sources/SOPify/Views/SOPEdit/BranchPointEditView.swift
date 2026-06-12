import SwiftUI
import SwiftData

struct BranchPointEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let step: Step

    @State private var question: String
    @State private var rejoinAfter: Bool
    @State private var showingNewOptionAlert = false
    @State private var optionLabelDraft = ""
    @State private var editingChildSOP: SOP?

    init(step: Step) {
        self.step = step
        _question = State(initialValue: step.branchQuestion ?? "")
        _rejoinAfter = State(initialValue: step.rejoinAfter)
    }

    private var orderedOptions: [BranchOption] {
        step.branchOptions.sorted(by: { $0.order < $1.order })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("e.g. Which route to take?", text: $question)
                }

                Section {
                    Toggle("Rejoin after branch", isOn: $rejoinAfter)
                } footer: {
                    Text("When enabled, execution continues with steps after this branch point once the chosen path is complete.")
                }

                Section("Options") {
                    ForEach(orderedOptions) { option in
                        Button {
                            editingChildSOP = fetchChild(id: option.targetSOPId)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.purple)
                                Text(option.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteOptions(at: indexSet)
                    }

                    Button {
                        optionLabelDraft = ""
                        showingNewOptionAlert = true
                    } label: {
                        Label("Add Option", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Branch Point")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
            }
            .alert("New Option", isPresented: $showingNewOptionAlert) {
                TextField("Option label", text: $optionLabelDraft)
                Button("Create") {
                    addOption(label: optionLabelDraft)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a label for this branch option.")
            }
            .sheet(item: $editingChildSOP) { childSOP in
                SOPEditView(editing: childSOP)
            }
        }
    }

    private func save() {
        let trimmed = question.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            step.branchQuestion = trimmed
            step.text = trimmed
        }
        step.rejoinAfter = rejoinAfter
        try? context.save()
        dismiss()
    }

    private func addOption(label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let childSOP = SOP(name: trimmed, type: .checklist)
        childSOP.parentStepId = step.id

        let option = BranchOption(label: trimmed, order: step.branchOptions.count, targetSOPId: childSOP.id)
        option.step = step

        context.insert(childSOP)
        context.insert(option)
        try? context.save()

        editingChildSOP = childSOP
    }

    private func deleteOptions(at indexSet: IndexSet) {
        let sorted = orderedOptions
        for index in indexSet {
            let option = sorted[index]
            if let child = fetchChild(id: option.targetSOPId) {
                context.delete(child)
            }
            context.delete(option)
        }
        try? context.save()
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
