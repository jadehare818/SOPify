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
    @State private var showingSubSOPSheet = false
    @State private var showingBranchAlert = false
    @State private var branchQuestionDraft = ""
    @State private var editingBranchStep: Step?
    @State private var showingTriggerSheet = false

    init(editing: SOP? = nil, isOneShot: Bool = false) {
        self.editing = editing
        self.isOneShot = editing?.isOneShot ?? isOneShot
        _name = State(initialValue: editing?.name ?? "")
        let texts = editing?.steps
            .sorted(by: { $0.order < $1.order })
            .filter { !$0.isNested && !$0.isBranch }
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
                            Text("Branching").tag(SOPType.branching)
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
                        Button {
                            selectedType = .branching
                        } label: {
                            Label("Upgrade to Branching", systemImage: "arrow.triangle.branch")
                        }
                    }
                }

                if let existing = editing, existing.type == .flow {
                    Section {
                        Button {
                            selectedType = .branching
                        } label: {
                            Label("Upgrade to Branching", systemImage: "arrow.triangle.branch")
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
                            showingSubSOPSheet = true
                        } label: {
                            Label("Add Sub-SOP", systemImage: "folder.badge.plus")
                        }
                    }
                }

                if let existingSOP = editing, selectedType == .branching {
                    Section("Branch Points") {
                        let branchSteps = existingSOP.steps
                            .filter { $0.isBranch }
                            .sorted(by: { $0.order < $1.order })
                        ForEach(branchSteps) { step in
                            Button {
                                editingBranchStep = step
                            } label: {
                                HStack {
                                    Label(step.branchQuestion ?? step.text, systemImage: "arrow.triangle.branch")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(step.branchOptions.count) options")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteBranchSteps(branchSteps: branchSteps, at: indexSet)
                        }
                        Button {
                            branchQuestionDraft = ""
                            showingBranchAlert = true
                        } label: {
                            Label("Add Branch Point", systemImage: "plus.circle")
                        }
                    }
                }

                if let existingSOP = editing, !isOneShot {
                    Section("Triggers") {
                        let triggerCount = existingSOP.triggers.count
                        Button {
                            showingTriggerSheet = true
                        } label: {
                            HStack {
                                Label("Manage Triggers", systemImage: "bell.badge")
                                Spacer()
                                if triggerCount > 0 {
                                    Text("\(triggerCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
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
            .sheet(isPresented: $showingSubSOPSheet) {
                if let parent = editing {
                    SubSOPPickerSheet(parent: parent) { childSOP in
                        nestedEditTarget = childSOP
                    }
                }
            }
            .alert("New Branch Point", isPresented: $showingBranchAlert) {
                TextField("Question (e.g. Which route?)", text: $branchQuestionDraft)
                Button("Create") {
                    addBranchPoint(question: branchQuestionDraft)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the decision question.")
            }
            .sheet(item: $editingBranchStep) { step in
                BranchPointEditView(step: step)
            }
            .sheet(isPresented: $showingTriggerSheet) {
                if let existingSOP = editing {
                    TriggerEditSheet(sop: existingSOP)
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
            existing.typeRaw = selectedType.rawValue

            // Preserve nested and branch steps, only delete plain text steps
            let nestedSteps = existing.steps.filter { $0.isNested }
            let branchSteps = existing.steps.filter { $0.isBranch }
            let plainSteps = existing.steps.filter { !$0.isNested && !$0.isBranch }
            for step in plainSteps {
                context.delete(step)
            }

            // Recreate plain text steps
            let newPlainSteps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }

            // Re-order nested steps after plain steps
            var baseOrder = newPlainSteps.count
            for (i, nested) in nestedSteps.enumerated() {
                nested.order = baseOrder + i
            }

            // Re-order branch steps after nested steps
            baseOrder += nestedSteps.count
            for (i, branch) in branchSteps.enumerated() {
                branch.order = baseOrder + i
            }

            existing.steps = newPlainSteps + nestedSteps + branchSteps
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

        let childSOP = SOP(name: trimmed, type: .checklist)
        let stepOrder = parent.steps.count
        let step = Step(text: trimmed, order: stepOrder, nestedSOPId: childSOP.id)
        childSOP.parentStepId = step.id

        context.insert(childSOP)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()

        nestedEditTarget = childSOP
    }

    private func linkExistingSOP(_ existingSOP: SOP) {
        guard let parent = editing else { return }
        let stepOrder = parent.steps.count
        let step = Step(text: existingSOP.name, order: stepOrder, nestedSOPId: existingSOP.id)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()
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

    private func addBranchPoint(question: String) {
        guard let parent = editing else { return }
        let trimmed = question.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let stepOrder = parent.steps.count
        let step = Step(text: trimmed, order: stepOrder, branchQuestion: trimmed)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()

        editingBranchStep = step
    }

    private func deleteBranchSteps(branchSteps: [Step], at indexSet: IndexSet) {
        guard let parent = editing else { return }
        for index in indexSet {
            let step = branchSteps[index]
            for option in step.branchOptions {
                if let child = fetchChild(id: option.targetSOPId) {
                    context.delete(child)
                }
                context.delete(option)
            }
            parent.steps.removeAll { $0.id == step.id }
            context.delete(step)
        }
        try? context.save()
    }
}

// MARK: - Sub-SOP Picker (create new or link existing)

struct SubSOPPickerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SOP.name) private var allSOPs: [SOP]

    let parent: SOP
    let onCreated: (SOP) -> Void

    @State private var mode: PickerMode = .choose
    @State private var newName = ""
    @State private var searchText = ""
    @State private var showingCycleAlert = false
    @State private var cycleAlertSOPName = ""

    enum PickerMode {
        case choose, createNew, linkExisting
    }

    private var linkableSOPs: [SOP] {
        let alreadyLinkedIds = Set(parent.steps.compactMap(\.nestedSOPId))
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
                            mode = .createNew
                        } label: {
                            Label("Create New", systemImage: "plus.circle")
                        }
                        Button {
                            mode = .linkExisting
                        } label: {
                            Label("Link Existing SOP", systemImage: "link")
                        }
                    }
                case .createNew:
                    Form {
                        Section("Name") {
                            TextField("Sub-SOP name", text: $newName)
                        }
                    }
                case .linkExisting:
                    List(linkableSOPs) { sop in
                        LinkableSOPRow(sop: sop) {
                            linkSOP(sop)
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
            .navigationTitle(mode == .choose ? "Add Sub-SOP" : (mode == .createNew ? "New Sub-SOP" : "Link Existing"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mode == .createNew {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            createNew()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if mode != .choose {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            mode = .choose
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
            .alert("Circular Dependency", isPresented: $showingCycleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\"\(cycleAlertSOPName)\" already contains this SOP (directly or indirectly). Linking it would create a cycle.")
            }
        }
    }

    private func createNew() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let childSOP = SOP(name: trimmed, type: .checklist)
        let stepOrder = parent.steps.count
        let step = Step(text: trimmed, order: stepOrder, nestedSOPId: childSOP.id)
        childSOP.parentStepId = step.id

        context.insert(childSOP)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()

        dismiss()
        onCreated(childSOP)
    }

    private func linkSOP(_ sop: SOP) {
        if wouldCreateCycle(linking: sop, to: parent) {
            cycleAlertSOPName = sop.name
            showingCycleAlert = true
            return
        }

        let stepOrder = parent.steps.count
        let step = Step(text: sop.name, order: stepOrder, nestedSOPId: sop.id)
        parent.steps.append(step)
        parent.updatedAt = .now
        try? context.save()
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
        let branchTargetIds = sop.steps.flatMap { $0.branchOptions.map(\.targetSOPId) }
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

private struct LinkableSOPRow: View {
    let sop: SOP
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
