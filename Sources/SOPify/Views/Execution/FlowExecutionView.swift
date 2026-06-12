import SwiftUI
import SwiftData

struct FlowExecutionView: View {
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
                                    toggle(step)
                                }
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
                    // Auto-complete the parent step when child finishes
                    if let step = orderedSteps.first(where: { $0.nestedSOPId == child.id }),
                       !completedStepIDs.contains(step.id) {
                        complete(step)
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
            for preceding in orderedSteps {
                if preceding.id == step.id { break }
                if !completedStepIDs.contains(preceding.id) {
                    completedStepIDs.insert(preceding.id)
                    let c = StepCompletion(stepId: preceding.id, completedAt: .now)
                    c.record = record
                    context.insert(c)
                }
            }
            completedStepIDs.insert(step.id)
            let completion = StepCompletion(stepId: step.id, completedAt: .now)
            completion.record = record
            context.insert(completion)
        }
        try? context.save()
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

// MARK: - Nested flow step row (shows drill-in button instead of "Done")

struct NestedFlowStepRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onDrillIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Step indicator
                ZStack {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: isCurrent ? 28 : 20))
                    } else if isCurrent {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "folder.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            )
                    } else {
                        Circle()
                            .strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "folder")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            )
                    }
                }
                .frame(width: 32)

                // Step content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(step.text)
                            .font(isCurrent ? .title3.weight(.semibold) : .body)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    if isCurrent {
                        Button(action: onDrillIn) {
                            Label("Start sub-SOP", systemImage: "arrow.right.circle.fill")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(.vertical, isCurrent ? 16 : 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? Color.orange.opacity(0.08) : Color.clear)
            )
        }
        .animation(.easeInOut(duration: 0.25), value: isCurrent)
        .animation(.easeInOut(duration: 0.25), value: isCompleted)
    }
}

#Preview {
    let sop = SOP(name: "Morning routine", type: .flow)
    sop.steps = [
        Step(text: "Wake up", order: 0),
        Step(text: "Brush teeth", order: 1),
        Step(text: "Make coffee", order: 2),
    ]
    return NavigationStack {
        FlowExecutionView(sop: sop)
    }
    .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                    inMemory: true)
}
