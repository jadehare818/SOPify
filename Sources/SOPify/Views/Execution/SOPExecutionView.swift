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
                    StepCheckRow(
                        step: step,
                        isCompleted: completedStepIDs.contains(step.id),
                        isCurrent: step.id == currentStepID
                    ) {
                        toggle(step)
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
        dismiss()
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
