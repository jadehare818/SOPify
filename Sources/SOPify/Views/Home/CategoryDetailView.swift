import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var context
    let category: Category?
    let title: String
    @Query(sort: \SOP.createdAt, order: .reverse) private var allSOPs: [SOP]
    @State private var editTarget: SOP?
    @State private var shareTarget: SOP?
    @State private var shareData: Data?
    @State private var showingShare = false

    private var sopsInCategory: [SOP] {
        if let category {
            return allSOPs.filter { $0.category?.id == category.id && !$0.isOneShot && !$0.isChild }
        } else {
            return allSOPs.filter { $0.category == nil && !$0.isOneShot && !$0.isChild }
        }
    }

    var body: some View {
        List {
            if sopsInCategory.isEmpty {
                ContentUnavailableView("No SOPs",
                                       systemImage: "checklist",
                                       description: Text("This category is empty."))
            } else {
                ForEach(sopsInCategory) { sop in
                    NavigationLink(value: sop) {
                        SOPRowView(sop: sop)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            context.delete(sop)
                            try? context.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editTarget = sop } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            exportSingle(sop)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .navigationTitle(title)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $editTarget) { sop in
            SOPEditView(editing: sop)
        }
        .navigationDestination(for: SOP.self) { sop in
            switch sop.type {
            case .checklist:
                SOPExecutionView(sop: sop)
            case .flow:
                FlowExecutionView(sop: sop)
            case .branching:
                BranchExecutionView(sop: sop)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let data = shareData {
                ShareSheet(data: data, filename: "\(shareTarget?.name ?? "sop").json")
            }
        }
    }

    private func exportSingle(_ sop: SOP) {
        do {
            shareData = try ExportService.exportSingle(sop: sop, context: context)
            shareTarget = sop
            showingShare = true
        } catch {}
    }
}
