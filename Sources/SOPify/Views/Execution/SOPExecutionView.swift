import SwiftUI
import SwiftData

struct SOPExecutionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP

    @State private var record: ExecutionRecord?
    @State private var completedStepIDs: Set<UUID> = []

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
