import SwiftUI
import SwiftData

struct SOPListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SOP.createdAt, order: .reverse) private var sops: [SOP]
    @State private var showingNewSheet = false
    @State private var editTarget: SOP?

    var body: some View {
        NavigationStack {
            List {
                if sops.isEmpty {
                    ContentUnavailableView("No SOPs yet",
                                           systemImage: "checklist",
                                           description: Text("Tap + to create your first SOP."))
                } else {
                    ForEach(sops) { sop in
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
                            Button {
                                editTarget = sop
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle("SOPify")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSheet) {
                SOPEditView()
            }
            .sheet(item: $editTarget) { sop in
                SOPEditView(editing: sop)
            }
            .navigationDestination(for: SOP.self) { sop in
                SOPExecutionView(sop: sop)
            }
        }
    }
}

#Preview {
    SOPListView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
}
