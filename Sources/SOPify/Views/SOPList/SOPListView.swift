import SwiftUI
import SwiftData

struct SOPListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SOP.createdAt, order: .reverse) private var sops: [SOP]
    @State private var showingNewSheet = false
    @State private var showingNewTempSheet = false
    @State private var editTarget: SOP?

    private var tempSOPs: [SOP] {
        sops.filter { $0.isOneShot }
    }

    private var regularSOPs: [SOP] {
        sops.filter { !$0.isOneShot }
    }

    var body: some View {
        NavigationStack {
            List {
                if !tempSOPs.isEmpty {
                    Section {
                        ForEach(tempSOPs) { sop in
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
                    } header: {
                        HStack {
                            Label("临时", systemImage: "bolt.fill")
                            Spacer()
                            Button {
                                showingNewTempSheet = true
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .font(.body)
                        }
                    }
                }

                if regularSOPs.isEmpty && tempSOPs.isEmpty {
                    ContentUnavailableView("No SOPs yet",
                                           systemImage: "checklist",
                                           description: Text("Tap + to create your first SOP."))
                } else if !regularSOPs.isEmpty {
                    Section("All SOPs") {
                        ForEach(regularSOPs) { sop in
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
            }
            .navigationTitle("SOPify")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingNewSheet = true
                        } label: {
                            Label("New SOP", systemImage: "plus")
                        }
                        Button {
                            showingNewTempSheet = true
                        } label: {
                            Label("临时 SOP", systemImage: "bolt")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSheet) {
                SOPEditView()
            }
            .sheet(isPresented: $showingNewTempSheet) {
                SOPEditView(isOneShot: true)
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
