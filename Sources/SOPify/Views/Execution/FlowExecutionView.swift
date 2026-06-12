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

                        FlowStepRow(
                            step: step,
                            isCompleted: isCompleted,
                            isCurrent: isCurrent
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                complete(step)
                            }
                            // Scroll to next step
                            if let nextID = currentStepID {
                                withAnimation {
                                    proxy.scrollTo(nextID, anchor: .center)
                                }
                            }
                        }
                        .id(step.id)
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
                NavigationLink {
                    SOPHistoryView(sop: sop)
                } label: {
                    Image(systemName: "clock")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    feedbackDraft = ""
                    showingFeedback = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(currentStepID == nil)
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let id = currentStepID, let step = orderedSteps.first(where: { $0.id == id }) {
                FeedbackSheet(stepText: step.text, draft: $feedbackDraft) { text in
                    saveFeedback(text, forStepID: id)
                }
            }
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
