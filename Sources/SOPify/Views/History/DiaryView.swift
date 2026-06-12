import SwiftUI
import SwiftData

struct DiaryView: View {
    @Query(sort: \ExecutionRecord.startedAt, order: .reverse) private var allRecords: [ExecutionRecord]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var selectedCategory: Category?
    @State private var showingFilter = false

    private var finishedRecords: [ExecutionRecord] {
        var records = allRecords.filter { $0.finishedAt != nil && $0.sop != nil }
        if let cat = selectedCategory {
            records = records.filter { $0.sop?.category?.id == cat.id }
        }
        return records
    }

    private var groupedByDay: [(String, [ExecutionRecord])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let groups = Dictionary(grouping: finishedRecords) { record in
            formatter.string(from: record.finishedAt ?? record.startedAt)
        }

        let sortedKeys = groups.keys.sorted { a, b in
            guard let recA = groups[a]?.first, let recB = groups[b]?.first else { return false }
            return (recA.finishedAt ?? recA.startedAt) > (recB.finishedAt ?? recB.startedAt)
        }

        return sortedKeys.map { ($0, groups[$0]!) }
    }

    var body: some View {
        List {
            if finishedRecords.isEmpty {
                ContentUnavailableView(
                    "No Records Yet",
                    systemImage: "book.closed",
                    description: Text("Complete an SOP to see it here.")
                )
            } else {
                ForEach(groupedByDay, id: \.0) { day, records in
                    Section(day) {
                        ForEach(records) { record in
                            DiaryRow(record: record)
                        }
                    }
                }
            }
        }
        .navigationTitle("Diary")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        selectedCategory = nil
                    } label: {
                        HStack {
                            Text("All")
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(categories) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            HStack {
                                Label(cat.name, systemImage: cat.icon)
                                if selectedCategory?.id == cat.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

struct DiaryRow: View {
    let record: ExecutionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.sop?.name ?? "Unknown")
                    .font(.headline)
                HStack(spacing: 8) {
                    if let sop = record.sop {
                        Text(sop.type.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.15))
                            )
                        if let catName = sop.category?.name {
                            Text(catName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(record.completions.count) steps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let finished = record.finishedAt {
                Text(finished, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
