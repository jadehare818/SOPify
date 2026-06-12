import SwiftUI
import SwiftData

struct SOPHistoryView: View {
    let sop: SOP

    @Query(sort: \ExecutionRecord.startedAt, order: .reverse)
    private var allRecords: [ExecutionRecord]

    private var records: [ExecutionRecord] {
        allRecords.filter { $0.sop?.id == sop.id }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("No runs yet",
                                       systemImage: "clock",
                                       description: Text("Execute this SOP to log a run."))
            } else {
                ForEach(records) { record in
                    NavigationLink(value: record) {
                        recordRow(record)
                    }
                }
            }
        }
        .navigationTitle("History")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: ExecutionRecord.self) { record in
            recordDetail(record)
        }
    }

    @ViewBuilder
    private func recordRow(_ record: ExecutionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.headline)
            HStack {
                if let finished = record.finishedAt {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(finished.timeIntervalSince(record.startedAt).formattedDuration())
                } else {
                    Label("Incomplete", systemImage: "circle.dashed")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("\(record.completions.count) steps")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func recordDetail(_ record: ExecutionRecord) -> some View {
        List {
            Section("Started") {
                Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
            }
            if let finished = record.finishedAt {
                Section("Finished") {
                    Text(finished.formatted(date: .abbreviated, time: .standard))
                }
            }
            Section("Step completions") {
                let sorted = record.completions.sorted(by: { $0.completedAt < $1.completedAt })
                if sorted.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stepText(for: c.stepId))
                            Text(c.completedAt.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let fb = c.feedbackText, !fb.isEmpty {
                                Text(fb)
                                    .font(.callout)
                                    .padding(8)
                                    #if os(macOS)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    #else
                                    .background(Color(.secondarySystemBackground))
                                    #endif
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Run details")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func stepText(for stepID: UUID) -> String {
        sop.steps.first(where: { $0.id == stepID })?.text ?? "(unknown step)"
    }
}

private extension TimeInterval {
    func formattedDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? ""
    }
}
