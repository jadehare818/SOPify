import SwiftUI
import SwiftData

struct SOPExecutionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP

    @State private var record: ExecutionRecord?
    @State private var completedStepIDs: Set<UUID> = []
    @State private var showingFeedback = false
    @State private var feedbackDraft = ""
    @State private var showingOneShotPrompt = false
    @State private var activeChildSOP: SOP?
    @State private var showingEdit = false

    private var orderedSteps: [Step] {
        sop.steps.sorted(by: { $0.order < $1.order })
    }

    private var currentStepID: UUID? {
        orderedSteps.first(where: { !completedStepIDs.contains($0.id) })?.id
    }

    private var isAllDone: Bool {
        !orderedSteps.isEmpty && completedStepIDs.count == orderedSteps.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(orderedSteps) { step in
                    if step.isNested {
                        NestedStepCheckRow(
                            step: step,
                            isCompleted: completedStepIDs.contains(step.id),
                            isCurrent: step.id == currentStepID
                        ) {
                            if let childId = step.nestedSOPId {
                                activeChildSOP = fetchChild(id: childId)
                            }
                        } onToggle: {
                            toggle(step)
                        }
                    } else {
                        StepCheckRow(
                            step: step,
                            isCompleted: completedStepIDs.contains(step.id),
                            isCurrent: step.id == currentStepID
                        ) {
                            toggle(step)
                        }
                    }
                }
                if isAllDone {
                    Button {
                        finish()
                    } label: {
                        Label("Mark complete", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
            }
            .padding()
        }
        .navigationTitle(sop.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { ensureRecord() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    feedbackDraft = ""
                    showingFeedback = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(currentStepID == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let id = currentStepID, let step = orderedSteps.first(where: { $0.id == id }) {
                FeedbackSheet(stepText: step.text, draft: $feedbackDraft) { text in
                    saveFeedback(text, forStepID: id)
                }
            }
        }
        .sheet(item: $activeChildSOP) { child in
            NavigationStack {
                NestedSOPExecutionWrapper(sop: child) {
                    activeChildSOP = nil
                    // Auto-complete the parent step that launched this child
                    if let step = orderedSteps.first(where: { $0.nestedSOPId == child.id }),
                       !completedStepIDs.contains(step.id) {
                        toggle(step)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            SOPEditView(editing: sop)
        }
        .alert("做完啦", isPresented: $showingOneShotPrompt) {
            Button("删了", role: .destructive) { deleteOneShot() }
            Button("留着") { dismiss() }
        } message: {
            Text("这条临时 SOP 还留着吗？")
        }
    }

    private func ensureRecord() {
        guard record == nil else { return }
        let r = ExecutionRecord(sop: sop, startedAt: .now)
        context.insert(r)
        try? context.save()
        record = r
    }

    private func toggle(_ step: Step) {
        guard let record else { return }
        if completedStepIDs.contains(step.id) {
            completedStepIDs.remove(step.id)
            if let latest = record.completions
                .filter({ $0.stepId == step.id })
                .sorted(by: { $0.completedAt > $1.completedAt })
                .first {
                context.delete(latest)
            }
        } else {
            completedStepIDs.insert(step.id)
            let completion = StepCompletion(stepId: step.id, completedAt: .now)
            completion.record = record
            context.insert(completion)
        }
        try? context.save()
    }

    private func saveFeedback(_ text: String, forStepID stepID: UUID) {
        guard let record else { return }
        if let latest = record.completions
            .filter({ $0.stepId == stepID })
            .sorted(by: { $0.completedAt > $1.completedAt })
            .first {
            latest.feedbackText = text
        } else {
            let completion = StepCompletion(stepId: stepID, completedAt: .now, feedbackText: text)
            completion.record = record
            context.insert(completion)
        }
        try? context.save()
    }

    private func finish() {
        record?.finishedAt = .now
        try? context.save()
        ChainedTriggerHelper.fireChainedTriggers(for: sop.id, context: context)
        if sop.isOneShot {
            showingOneShotPrompt = true
        } else {
            dismiss()
        }
    }

    private func deleteOneShot() {
        context.delete(sop)
        try? context.save()
        dismiss()
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

// MARK: - Nested step row for checklist mode

struct NestedStepCheckRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onDrillIn: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(isCurrent ? .system(size: 32) : .system(size: 24))
                    .foregroundStyle(isCompleted ? .green : (isCurrent ? .accentColor : .secondary))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(step.text)
                        .font(isCurrent ? .title3.weight(.semibold) : .body)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)
                }

                if isCurrent && !isCompleted {
                    Button(action: onDrillIn) {
                        Label("Open sub-SOP", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.vertical, isCurrent ? 12 : 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Color.orange.opacity(0.08) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}

// MARK: - Wrapper for executing a nested SOP in a sheet

struct NestedSOPExecutionWrapper: View {
    @Environment(\.dismiss) private var dismiss
    let sop: SOP
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch sop.type {
            case .checklist:
                NestedChecklistExecution(sop: sop, onComplete: onComplete)
            case .flow:
                NestedFlowExecution(sop: sop, onComplete: onComplete)
            case .branching:
                NestedBranchExecution(sop: sop, onComplete: onComplete)
            }
        }
        .navigationTitle(sop.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
    }
}

// MARK: - Nested checklist execution (simplified, no history tracking)

struct NestedChecklistExecution: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP
    let onComplete: () -> Void

    @State private var completedStepIDs: Set<UUID> = []
    @State private var activeChildSOP: SOP?

    private var orderedSteps: [Step] {
        sop.steps.sorted(by: { $0.order < $1.order })
    }

    private var currentStepID: UUID? {
        orderedSteps.first(where: { !completedStepIDs.contains($0.id) })?.id
    }

    private var isAllDone: Bool {
        !orderedSteps.isEmpty && completedStepIDs.count == orderedSteps.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(orderedSteps) { step in
                    if step.isNested {
                        NestedStepCheckRow(
                            step: step,
                            isCompleted: completedStepIDs.contains(step.id),
                            isCurrent: step.id == currentStepID
                        ) {
                            if let childId = step.nestedSOPId {
                                activeChildSOP = fetchChild(id: childId)
                            }
                        } onToggle: {
                            toggleStep(step)
                        }
                    } else {
                        StepCheckRow(
                            step: step,
                            isCompleted: completedStepIDs.contains(step.id),
                            isCurrent: step.id == currentStepID
                        ) {
                            toggleStep(step)
                        }
                    }
                }
                if isAllDone {
                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Label("Done — return to parent", systemImage: "arrow.uturn.backward.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 16)
                }
            }
            .padding()
        }
        .sheet(item: $activeChildSOP) { child in
            NavigationStack {
                NestedSOPExecutionWrapper(sop: child) {
                    activeChildSOP = nil
                    if let step = orderedSteps.first(where: { $0.nestedSOPId == child.id }),
                       !completedStepIDs.contains(step.id) {
                        toggleStep(step)
                    }
                }
            }
        }
    }

    private func toggleStep(_ step: Step) {
        if completedStepIDs.contains(step.id) {
            completedStepIDs.remove(step.id)
        } else {
            completedStepIDs.insert(step.id)
        }
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

// MARK: - Nested flow execution (simplified, no history tracking)

struct NestedFlowExecution: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP
    let onComplete: () -> Void

    @State private var completedStepIDs: Set<UUID> = []
    @State private var activeChildSOP: SOP?

    private var orderedSteps: [Step] {
        sop.steps.sorted(by: { $0.order < $1.order })
    }

    private var currentStepID: UUID? {
        orderedSteps.first(where: { !completedStepIDs.contains($0.id) })?.id
    }

    private var isAllDone: Bool {
        !orderedSteps.isEmpty && completedStepIDs.count == orderedSteps.count
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(orderedSteps) { step in
                        let isCompleted = completedStepIDs.contains(step.id)
                        let isCurrent = step.id == currentStepID

                        if step.isNested {
                            NestedFlowStepRow(
                                step: step,
                                isCompleted: isCompleted,
                                isCurrent: isCurrent
                            ) {
                                if let childId = step.nestedSOPId {
                                    activeChildSOP = fetchChild(id: childId)
                                }
                            }
                            .id(step.id)
                        } else {
                            FlowStepRow(
                                step: step,
                                isCompleted: isCompleted,
                                isCurrent: isCurrent
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    completedStepIDs.insert(step.id)
                                }
                                if let nextID = orderedSteps.first(where: { !completedStepIDs.contains($0.id) && $0.id != step.id })?.id {
                                    withAnimation {
                                        proxy.scrollTo(nextID, anchor: .center)
                                    }
                                }
                            }
                            .id(step.id)
                        }
                    }

                    if isAllDone {
                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            Label("Done — return to parent", systemImage: "arrow.uturn.backward.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .padding(.top, 16)
                    }
                }
                .padding()
            }
        }
        .sheet(item: $activeChildSOP) { child in
            NavigationStack {
                NestedSOPExecutionWrapper(sop: child) {
                    activeChildSOP = nil
                    if let step = orderedSteps.first(where: { $0.nestedSOPId == child.id }),
                       !completedStepIDs.contains(step.id) {
                        completedStepIDs.insert(step.id)
                    }
                }
            }
        }
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

#Preview {
    let sop = SOP(name: "Pack for swim")
    sop.steps = [
        Step(text: "Swim trunks", order: 0),
        Step(text: "Goggles", order: 1),
        Step(text: "Towel", order: 2),
    ]
    return NavigationStack {
        SOPExecutionView(sop: sop)
    }
    .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                    inMemory: true)
}
