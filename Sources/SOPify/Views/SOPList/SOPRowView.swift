import SwiftUI
import SwiftData

struct SOPRowView: View {
    let sop: SOP

    @Query private var records: [ExecutionRecord]

    init(sop: SOP) {
        self.sop = sop
        let sopID = sop.id
        let predicate = #Predicate<ExecutionRecord> {
            $0.sop?.id == sopID && $0.finishedAt != nil
        }
        _records = Query(filter: predicate, sort: \ExecutionRecord.finishedAt, order: .reverse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(sop.name)
                    .font(.headline)
                if sop.type == .flow {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            HStack {
                Text("\(sop.steps.count) steps")
                if let last = records.first?.finishedAt {
                    Text("•")
                    Text("Last: \(last, format: .relative(presentation: .named))")
                }
                if !records.isEmpty {
                    Text("•")
                    Text("\(records.count) run\(records.count == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SOPRowView(sop: SOP(name: "Morning routine"))
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
        .padding()
}
