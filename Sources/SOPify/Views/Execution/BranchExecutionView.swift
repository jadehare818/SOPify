import SwiftUI
import SwiftData

struct BranchExecutionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP

    @State private var record: ExecutionRecord?
    @State private var completedStepIDs: Set<UUID> = []
    @State private var showingFeedback = false
    @State private var feedbackDraft = ""
    @State private var showingOneShotPrompt = false
    @State private var activeChildSOP: SOP?
    @State private var activeBranchOptions: (step: Step, options: [BranchOption])?
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(orderedSteps) { step in
                        let isCompleted = completedStepIDs.contains(step.id)
                        let isCurrent = step.id == currentStepID

                        if step.isBranch {
                            BranchStepRow(
                                step: step,
                                isCompleted: isCompleted,
                                isCurrent: isCurrent
                            ) {
                                let options = step.branchOptions.sorted(by: { $0.order < $1.order })
                                activeBranchOptions = (step: step, options: options)
                            }
                            .id(step.id)
                        } else if step.isNested {
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
                                    complete(step)
                                }
                                scrollToNext(proxy: proxy, excluding: step.id)
                            }
                            .id(step.id)
                        }
                    }

                    if isAllDone {
                        Button {
                            finish()
                        } label: {
                            Label("Done", systemImage: "flag.checkered")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 16)
                    }
                }
                .padding()
            }
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
                    // Mark the parent step complete — could be a nested step or a branch step
                    if let step = orderedSteps.first(where: { $0.nestedSOPId == child.id }),
                       !completedStepIDs.contains(step.id) {
                        complete(step)
                    } else if let step = orderedSteps.first(where: { $0.isBranch && $0.branchOptions.contains(where: { $0.targetSOPId == child.id }) }),
                              !completedStepIDs.contains(step.id) {
                        complete(step)
                    }
                }
            }
        }
        .sheet(isPresented: branchSheetBinding) {
            if let data = activeBranchOptions {
                BranchChoiceSheet(step: data.step, options: data.options) { option in
                    activeBranchOptions = nil
                    if let sopId = option.targetSOPId {
                        activeChildSOP = fetchChild(id: sopId)
                    } else {
                        if let step = orderedSteps.first(where: { $0.id == data.step.id }),
                           !completedStepIDs.contains(step.id) {
                            complete(step)
                        }
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

    private var branchSheetBinding: Binding<Bool> {
        Binding(
            get: { activeBranchOptions != nil },
            set: { if !$0 { activeBranchOptions = nil } }
        )
    }

    private func scrollToNext(proxy: ScrollViewProxy, excluding stepId: UUID) {
        if let nextID = orderedSteps.first(where: { !completedStepIDs.contains($0.id) && $0.id != stepId })?.id {
            withAnimation {
                proxy.scrollTo(nextID, anchor: .center)
            }
        }
    }

    private func ensureRecord() {
        guard record == nil else { return }
        let r = ExecutionRecord(sop: sop, startedAt: .now)
        context.insert(r)
        try? context.save()
        record = r
    }

    private func complete(_ step: Step) {
        guard let record, !completedStepIDs.contains(step.id) else { return }
        completedStepIDs.insert(step.id)
        let completion = StepCompletion(stepId: step.id, completedAt: .now)
        completion.record = record
        context.insert(completion)
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

// MARK: - Branch step row

struct BranchStepRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: isCurrent ? 28 : 20))
                    } else if isCurrent {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            )
                    } else {
                        Circle()
                            .strokeBorder(Color.purple.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.purple)
                            )
                    }
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.branchQuestion ?? step.text)
                        .font(isCurrent ? .title3.weight(.semibold) : .body)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    if isCurrent && !isCompleted {
                        Button(action: onChoose) {
                            Label("Choose path", systemImage: "arrow.triangle.branch")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(.vertical, isCurrent ? 16 : 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? Color.purple.opacity(0.08) : Color.clear)
            )
        }
        .animation(.easeInOut(duration: 0.25), value: isCurrent)
        .animation(.easeInOut(duration: 0.25), value: isCompleted)
    }
}

// MARK: - Branch choice sheet

struct BranchChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: Step
    let options: [BranchOption]
    let onSelect: (BranchOption) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(step.branchQuestion ?? "Choose a path")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: option.isSimpleAction ? "text.bubble.fill" : "arrow.right.circle.fill")
                                    .foregroundStyle(option.isSimpleAction ? .orange : .purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.headline)
                                    if option.isSimpleAction, let action = option.actionText, action != option.label {
                                        Text(action)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: option.isSimpleAction ? "checkmark" : "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Branch")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if !os(macOS)
        .presentationDetents([.medium])
        #endif
    }
}

// MARK: - Nested branch execution (for use inside sheets)

struct NestedBranchExecution: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP
    let onComplete: () -> Void

    @State private var completedStepIDs: Set<UUID> = []
    @State private var activeChildSOP: SOP?
    @State private var activeBranchOptions: (step: Step, options: [BranchOption])?

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

                        if step.isBranch {
                            BranchStepRow(
                                step: step,
                                isCompleted: isCompleted,
                                isCurrent: isCurrent
                            ) {
                                let options = step.branchOptions.sorted(by: { $0.order < $1.order })
                                activeBranchOptions = (step: step, options: options)
                            }
                            .id(step.id)
                        } else if step.isNested {
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
                        .tint(.purple)
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
        .sheet(isPresented: branchSheetBinding) {
            if let data = activeBranchOptions {
                BranchChoiceSheet(step: data.step, options: data.options) { option in
                    activeBranchOptions = nil
                    if let sopId = option.targetSOPId {
                        activeChildSOP = fetchChild(id: sopId)
                    } else {
                        if let step = orderedSteps.first(where: { $0.id == data.step.id }),
                           !completedStepIDs.contains(step.id) {
                            completedStepIDs.insert(step.id)
                        }
                    }
                }
            }
        }
    }

    private var branchSheetBinding: Binding<Bool> {
        Binding(
            get: { activeBranchOptions != nil },
            set: { if !$0 { activeBranchOptions = nil } }
        )
    }

    private func fetchChild(id: UUID) -> SOP? {
        let descriptor = FetchDescriptor<SOP>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

#Preview {
    let sop = SOP(name: "Decide route", type: .branching)
    let branchStep = Step(text: "Which route?", order: 0, branchQuestion: "How do you want to get there?")
    sop.steps = [
        Step(text: "Check weather", order: 0),
        branchStep,
        Step(text: "Arrive", order: 2),
    ]
    return NavigationStack {
        BranchExecutionView(sop: sop)
    }
    .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, BranchOption.self],
                    inMemory: true)
}
