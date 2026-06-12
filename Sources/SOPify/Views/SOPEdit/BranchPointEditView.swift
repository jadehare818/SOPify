import SwiftUI
import SwiftData

struct BranchPointEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let step: Step

    @State private var question: String
    @State private var rejoinAfter: Bool
    @State private var showingAddOption = false
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
                Section("Condition / Question") {
                    TextField("e.g. 现在几点？", text: $question)
                }

                Section {
                    Toggle("Rejoin after branch", isOn: $rejoinAfter)
                } footer: {
                    Text("When enabled, execution continues with steps after this branch point once the chosen path is complete.")
                }

                Section("Options") {
                    ForEach(orderedOptions) { option in
                        BranchOptionRow(option: option) {
                            if let sopId = option.targetSOPId {
                                editingChildSOP = fetchChild(id: sopId)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteOptions(at: indexSet)
                    }

                    Button {
                        showingAddOption = true
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
            .sheet(isPresented: $showingAddOption) {
                AddBranchOptionSheet(step: step)
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

    private func deleteOptions(at indexSet: IndexSet) {
        let sorted = orderedOptions
        for index in indexSet {
            let option = sorted[index]
            if let sopId = option.targetSOPId, let child = fetchChild(id: sopId) {
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

// MARK: - Option row

private struct BranchOptionRow: View {
    let option: BranchOption
    let onEditSOP: () -> Void

    var body: some View {
        if option.isSimpleAction {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(option.label).foregroundStyle(.primary)
                    if let action = option.actionText, !action.isEmpty {
                        Text(action)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        } else {
            Button(action: onEditSOP) {
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
    }
}

// MARK: - Add option sheet

struct AddBranchOptionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let step: Step

    @State private var mode: OptionMode = .choose
    @State private var label = ""
    @State private var actionText = ""

    enum OptionMode {
        case choose, textAction, subSOP
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .choose:
                    List {
                        Button {
                            mode = .textAction
                        } label: {
                            Label("Text Action", systemImage: "text.bubble")
                                .foregroundStyle(.primary)
                        }
                        Button {
                            mode = .subSOP
                        } label: {
                            Label("Sub-SOP", systemImage: "folder.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                case .textAction:
                    Form {
                        Section("Option Label") {
                            TextField("e.g. 早上九点", text: $label)
                        }
                        Section("Action") {
                            TextField("e.g. 出门上班", text: $actionText)
                        }
                    }
                case .subSOP:
                    Form {
                        Section("Option Label") {
                            TextField("e.g. Route A", text: $label)
                        }
                    }
                }
            }
            .navigationTitle(mode == .choose ? "Add Option" : (mode == .textAction ? "Text Action" : "Sub-SOP"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mode != .choose {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { addOption() }
                            .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ToolbarItem(placement: .navigation) {
                        Button { mode = .choose } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    private func addOption() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }

        switch mode {
        case .textAction:
            let trimmedAction = actionText.trimmingCharacters(in: .whitespaces)
            let option = BranchOption(
                label: trimmedLabel,
                order: step.branchOptions.count,
                actionText: trimmedAction.isEmpty ? trimmedLabel : trimmedAction
            )
            option.step = step
            context.insert(option)

        case .subSOP:
            let childSOP = SOP(name: trimmedLabel, type: .checklist)
            childSOP.parentStepId = step.id
            context.insert(childSOP)

            let option = BranchOption(
                label: trimmedLabel,
                order: step.branchOptions.count,
                targetSOPId: childSOP.id
            )
            option.step = step
            context.insert(option)

        case .choose:
            return
        }

        try? context.save()
        dismiss()
    }
}
