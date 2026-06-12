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
    @Query(sort: \SOP.name) private var allSOPs: [SOP]

    let step: Step

    @State private var mode: OptionMode = .choose
    @State private var label = ""
    @State private var actionText = ""
    @State private var subSOPMode: SubSOPMode = .pick
    @State private var newSOPName = ""
    @State private var searchText = ""
    @State private var showingCycleAlert = false

    enum OptionMode {
        case choose, textAction, subSOP
    }

    enum SubSOPMode {
        case pick, createNew, linkExisting
    }

    private var parentSOP: SOP? { step.sop }

    private var linkableSOPs: [SOP] {
        guard let parent = parentSOP else { return [] }
        let alreadyLinkedIds = Set(step.branchOptions.compactMap(\.targetSOPId))
        return allSOPs.filter { sop in
            sop.id != parent.id &&
            !alreadyLinkedIds.contains(sop.id) &&
            !sop.isOneShot &&
            (searchText.isEmpty || sop.name.localizedCaseInsensitiveContains(searchText))
        }
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
                            subSOPMode = .pick
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
                    subSOPContent
                }
            }
            .navigationTitle(navigationTitle)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mode == .textAction {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { addTextAction() }
                            .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ToolbarItem(placement: .navigation) {
                        Button { mode = .choose } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                if mode == .subSOP {
                    if subSOPMode == .createNew {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") { createNewSubSOP() }
                                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || newSOPName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    ToolbarItem(placement: .navigation) {
                        Button {
                            if subSOPMode == .pick {
                                mode = .choose
                            } else {
                                subSOPMode = .pick
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
            .alert("Circular Dependency", isPresented: $showingCycleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This SOP already contains the current branch (directly or indirectly). Linking it would create a cycle.")
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .choose: return "Add Option"
        case .textAction: return "Text Action"
        case .subSOP:
            switch subSOPMode {
            case .pick: return "Sub-SOP"
            case .createNew: return "New Sub-SOP"
            case .linkExisting: return "Link Existing"
            }
        }
    }

    @ViewBuilder
    private var subSOPContent: some View {
        switch subSOPMode {
        case .pick:
            List {
                Button { subSOPMode = .createNew } label: {
                    Label("Create New", systemImage: "plus.circle")
                }
                Button { subSOPMode = .linkExisting } label: {
                    Label("Link Existing SOP", systemImage: "link")
                }
            }
        case .createNew:
            Form {
                Section("Option Label") {
                    TextField("e.g. Route A", text: $label)
                }
                Section("New SOP Name") {
                    TextField("e.g. 走高速路线", text: $newSOPName)
                }
            }
        case .linkExisting:
            VStack {
                if label.trimmingCharacters(in: .whitespaces).isEmpty {
                    Form {
                        Section("Option Label") {
                            TextField("e.g. Route A", text: $label)
                        }
                    }
                    .frame(height: 100)
                }
                List(linkableSOPs) { sop in
                    Button {
                        linkExistingSOP(sop)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sop.name).foregroundStyle(.primary)
                                Text("\(sop.steps.count) steps · \(sop.type.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .overlay {
                    if linkableSOPs.isEmpty {
                        ContentUnavailableView("No SOPs Available",
                                               systemImage: "tray",
                                               description: Text("All SOPs are already linked or none exist."))
                    }
                }
                .searchable(text: $searchText, prompt: "Search SOPs")
            }
        }
    }

    private func addTextAction() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }
        let trimmedAction = actionText.trimmingCharacters(in: .whitespaces)
        let option = BranchOption(
            label: trimmedLabel,
            order: step.branchOptions.count,
            actionText: trimmedAction.isEmpty ? trimmedLabel : trimmedAction
        )
        option.step = step
        context.insert(option)
        dismiss()
    }

    private func createNewSubSOP() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let trimmedName = newSOPName.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty, !trimmedName.isEmpty else { return }

        let childSOP = SOP(name: trimmedName, type: .checklist)
        childSOP.parentStepId = step.id
        context.insert(childSOP)

        let option = BranchOption(
            label: trimmedLabel,
            order: step.branchOptions.count,
            targetSOPId: childSOP.id
        )
        option.step = step
        context.insert(option)
        dismiss()
    }

    private func linkExistingSOP(_ sop: SOP) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let finalLabel = trimmedLabel.isEmpty ? sop.name : trimmedLabel

        if let parent = parentSOP, wouldCreateCycle(linking: sop, to: parent) {
            showingCycleAlert = true
            return
        }

        let option = BranchOption(
            label: finalLabel,
            order: step.branchOptions.count,
            targetSOPId: sop.id
        )
        option.step = step
        context.insert(option)
        dismiss()
    }

    private func wouldCreateCycle(linking candidate: SOP, to parent: SOP) -> Bool {
        var visited = Set<UUID>()
        return hasPath(from: candidate, to: parent.id, visited: &visited)
    }

    private func hasPath(from sop: SOP, to targetId: UUID, visited: inout Set<UUID>) -> Bool {
        if sop.id == targetId { return true }
        if visited.contains(sop.id) { return false }
        visited.insert(sop.id)

        let nestedIds = sop.steps.compactMap(\.nestedSOPId)
        let branchTargetIds = sop.steps.flatMap { $0.branchOptions.compactMap(\.targetSOPId) }
        let allChildIds = nestedIds + branchTargetIds

        for childId in allChildIds {
            if childId == targetId { return true }
            let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == childId })
            if let child = try? context.fetch(descriptor).first {
                if hasPath(from: child, to: targetId, visited: &visited) {
                    return true
                }
            }
        }
        return false
    }
}
