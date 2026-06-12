import SwiftUI
import SwiftData

struct SOPEditView: View {
    @Environment(\.modelContext) private var parentContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]

    let initialEditingId: UUID?
    let isOneShot: Bool

    @State private var editContext: ModelContext?
    @State private var editingSOP: SOP?
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedType: SOPType = .checklist
    @State private var nestedEditTarget: SOP?
    @State private var showingSubSOPSheet = false
    @State private var showingBranchAlert = false
    @State private var branchQuestionDraft = ""
    @State private var editingBranchStep: Step?
    @State private var showingTriggerSheet = false
    @State private var isReady = false

    private var editing: SOP? { editingSOP }

    init(editing: SOP? = nil, isOneShot: Bool = false) {
        self.initialEditingId = editing?.id
        self.isOneShot = editing?.isOneShot ?? isOneShot
        _name = State(initialValue: editing?.name ?? "")
        _selectedCategory = State(initialValue: editing?.category)
        _selectedType = State(initialValue: editing?.type ?? .checklist)
    }

    private var orderedSteps: [Step] {
        editing?.steps.sorted(by: { $0.order < $1.order }) ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if isReady {
                    formContent
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(editingSOP == nil ? (isOneShot ? "临时 SOP" : "New SOP") : "Edit SOP")
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
            .onAppear { setupEditContext() }
        }
    }

    @ViewBuilder
    private var formContent: some View {
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

            if initialEditingId == nil && editingSOP == nil && !isOneShot {
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
                    Button { selectedType = .flow } label: {
                        Label("Upgrade to Flow", systemImage: "arrow.up.circle")
                    }
                    Button { selectedType = .branching } label: {
                        Label("Upgrade to Branching", systemImage: "arrow.triangle.branch")
                    }
                }
            }

            if let existing = editing, existing.type == .flow {
                Section {
                    Button { selectedType = .branching } label: {
                        Label("Upgrade to Branching", systemImage: "arrow.triangle.branch")
                    }
                }
            }

            // MARK: - Steps section (unified)
            Section("Steps") {
                if editing != nil {
                    ForEach(orderedSteps) { step in
                        EditStepRow(step: step, onEditNested: {
                            if let childId = step.nestedSOPId {
                                nestedEditTarget = fetchChild(id: childId)
                            }
                        }, onEditBranch: {
                            editingBranchStep = step
                        })
                    }
                    .onDelete { indexSet in
                        deleteSteps(at: indexSet)
                    }
                    .onMove { source, destination in
                        moveSteps(from: source, to: destination)
                    }
                }

                Menu {
                    Button { addTextStep() } label: {
                        Label("Text Step", systemImage: "text.badge.plus")
                    }
                    Button { addSubSOP() } label: {
                        Label("Sub-SOP", systemImage: "folder.badge.plus")
                    }
                    if selectedType == .branching {
                        Button {
                            branchQuestionDraft = ""
                            showingBranchAlert = true
                        } label: {
                            Label("Branch Point", systemImage: "arrow.triangle.branch")
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
            }

            if let existingSOP = editing, !isOneShot {
                Section("Triggers") {
                    let triggerCount = existingSOP.triggers.count
                    Button { showingTriggerSheet = true } label: {
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
        .sheet(item: $nestedEditTarget) { childSOP in
            SOPEditView(editing: childSOP)
        }
        .sheet(isPresented: $showingSubSOPSheet) {
            if let ctx = editContext, let parent = editing {
                SubSOPPickerSheet(parent: parent) { childSOP in
                    nestedEditTarget = childSOP
                }
                .modelContext(ctx)
            }
        }
        .alert("New Branch Point", isPresented: $showingBranchAlert) {
            TextField("e.g. 现在几点？", text: $branchQuestionDraft)
            Button("Create") {
                addBranchPoint(question: branchQuestionDraft)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the condition or question.")
        }
        .sheet(item: $editingBranchStep) { step in
            if let ctx = editContext {
                BranchPointEditView(step: step)
                    .modelContext(ctx)
            }
        }
        .sheet(isPresented: $showingTriggerSheet) {
            if let existingSOP = editing {
                TriggerEditSheet(sop: existingSOP)
            }
        }
    }

    // MARK: - Edit context setup

    private func setupEditContext() {
        guard editContext == nil else { return }
        let ctx = ModelContext(parentContext.container)
        ctx.autosaveEnabled = false
        editContext = ctx

        if let id = initialEditingId {
            let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
            editingSOP = try? ctx.fetch(descriptor).first
            if let sop = editingSOP {
                name = sop.name
                selectedCategory = sop.category
                selectedType = sop.type
            }
        }
        isReady = true
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save

    private func save() {
        guard let ctx = editContext else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let existing = editing {
            existing.name = trimmedName
            existing.updatedAt = .now
            // Find category in edit context
            if let catId = selectedCategory?.id {
                let catDesc = FetchDescriptor<Category>(predicate: #Predicate { $0.id == catId })
                existing.category = try? ctx.fetch(catDesc).first
            } else {
                existing.category = nil
            }
            existing.typeRaw = selectedType.rawValue
        } else {
            let sop = SOP(name: trimmedName, type: selectedType, isOneShot: isOneShot)
            if let catId = selectedCategory?.id {
                let catDesc = FetchDescriptor<Category>(predicate: #Predicate { $0.id == catId })
                sop.category = try? ctx.fetch(catDesc).first
            }
            ctx.insert(sop)
        }

        try? ctx.save()
        dismiss()
    }

    // MARK: - Lazy SOP creation (auto-persist when adding steps in new mode)

    @discardableResult
    private func ensurePersisted() -> SOP {
        if let existing = editing { return existing }
        guard let ctx = editContext else { fatalError() }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let sop = SOP(name: trimmedName.isEmpty ? "Untitled" : trimmedName, type: selectedType, isOneShot: isOneShot)
        if let catId = selectedCategory?.id {
            let catDesc = FetchDescriptor<Category>(predicate: #Predicate { $0.id == catId })
            sop.category = try? ctx.fetch(catDesc).first
        }
        ctx.insert(sop)
        editingSOP = sop
        return sop
    }

    // MARK: - Step management

    private func addTextStep() {
        let parent = ensurePersisted()
        let order = parent.steps.count
        let step = Step(text: "", order: order)
        parent.steps.append(step)
        parent.updatedAt = .now
    }

    private func addSubSOP() {
        ensurePersisted()
        showingSubSOPSheet = true
    }

    private func addBranchPoint(question: String) {
        let parent = ensurePersisted()
        let trimmed = question.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let stepOrder = parent.steps.count
        let step = Step(text: trimmed, order: stepOrder, branchQuestion: trimmed)
        parent.steps.append(step)
        parent.updatedAt = .now

        editingBranchStep = step
    }

    private func deleteSteps(at indexSet: IndexSet) {
        guard let ctx = editContext, let parent = editing else { return }
        let steps = orderedSteps
        for index in indexSet {
            let step = steps[index]
            if let childId = step.nestedSOPId, let child = fetchChild(id: childId) {
                ctx.delete(child)
            }
            if step.isBranch {
                for option in step.branchOptions {
                    if let sopId = option.targetSOPId, let child = fetchChild(id: sopId) {
                        ctx.delete(child)
                    }
                    ctx.delete(option)
                }
            }
            parent.steps.removeAll { $0.id == step.id }
            ctx.delete(step)
        }
        reorderSteps(parent)
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        guard let parent = editing else { return }
        var steps = orderedSteps
        steps.move(fromOffsets: source, toOffset: destination)
        for (i, step) in steps.enumerated() {
            step.order = i
        }
        parent.updatedAt = .now
    }

    private func reorderSteps(_ parent: SOP) {
        let sorted = parent.steps.sorted(by: { $0.order < $1.order })
        for (i, step) in sorted.enumerated() {
            step.order = i
        }
    }

    private func fetchChild(id: UUID) -> SOP? {
        guard let ctx = editContext else { return nil }
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? ctx.fetch(descriptor).first
    }
}

// MARK: - Unified step row in edit mode

private struct EditStepRow: View {
    let step: Step
    let onEditNested: () -> Void
    let onEditBranch: () -> Void

    @State private var text: String

    init(step: Step, onEditNested: @escaping () -> Void, onEditBranch: @escaping () -> Void) {
        self.step = step
        self.onEditNested = onEditNested
        self.onEditBranch = onEditBranch
        _text = State(initialValue: step.text)
    }

    var body: some View {
        if step.isNested {
            Button(action: onEditNested) {
                HStack {
                    Label(step.text, systemImage: "folder.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } else if step.isBranch {
            Button(action: onEditBranch) {
                HStack {
                    Label(step.branchQuestion ?? step.text, systemImage: "arrow.triangle.branch")
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("\(step.branchOptions.count) options")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            TextField("Step", text: $text)
                .onChange(of: text) { _, newValue in
                    step.text = newValue
                }
        }
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
                        Button { mode = .createNew } label: {
                            Label("Create New", systemImage: "plus.circle")
                        }
                        Button { mode = .linkExisting } label: {
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
                        LinkableSOPRow(sop: sop) { linkSOP(sop) }
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
                        Button("Create") { createNew() }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if mode != .choose {
                    ToolbarItem(placement: .navigation) {
                        Button { mode = .choose } label: {
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
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self, BranchOption.self, Trigger.self],
                        inMemory: true)
}

#Preview("Temp") {
    SOPEditView(isOneShot: true)
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self, BranchOption.self, Trigger.self],
                        inMemory: true)
}
