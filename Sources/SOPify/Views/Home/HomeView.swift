import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \SOP.createdAt, order: .reverse) private var allSOPs: [SOP]
    @Query(sort: \ExecutionRecord.startedAt, order: .reverse) private var recentRecords: [ExecutionRecord]
    @State private var showingNewSheet = false
    @State private var showingNewTempSheet = false
    @State private var editTarget: SOP?
    @State private var searchText = ""

    private var tempSOPs: [SOP] {
        allSOPs.filter { $0.isOneShot }
    }

    private var uncategorizedSOPs: [SOP] {
        allSOPs.filter { !$0.isOneShot && $0.category == nil }
    }

    private var filteredSOPs: [SOP] {
        guard !searchText.isEmpty else { return [] }
        return allSOPs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var recentFinished: [ExecutionRecord] {
        Array(recentRecords.filter { $0.finishedAt != nil }.prefix(5))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty {
                    Section("Search results") {
                        if filteredSOPs.isEmpty {
                            Text("No results").foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredSOPs) { sop in
                                NavigationLink(value: sop) {
                                    SOPRowView(sop: sop)
                                }
                            }
                        }
                    }
                } else {
                    // Temp section
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
                                    Button { editTarget = sop } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        } header: {
                            HStack {
                                Label("临时", systemImage: "bolt.fill")
                                Spacer()
                                Button { showingNewTempSheet = true } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .font(.body)
                            }
                        }
                    }

                    // Category grid
                    Section("Categories") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(categories) { cat in
                                NavigationLink(value: cat) {
                                    CategoryCardView(category: cat)
                                }
                                .buttonStyle(.plain)
                            }
                            if !uncategorizedSOPs.isEmpty {
                                NavigationLink {
                                    CategoryDetailView(category: nil, title: "Uncategorized")
                                } label: {
                                    UncategorizedCardView(count: uncategorizedSOPs.count)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Recent runs
                    if !recentFinished.isEmpty {
                        Section("Recent") {
                            ForEach(recentFinished) { record in
                                if let sop = record.sop {
                                    NavigationLink(value: sop) {
                                        HStack {
                                            Text(sop.name)
                                                .font(.subheadline)
                                            Spacer()
                                            if let finished = record.finishedAt {
                                                Text(finished, format: .relative(presentation: .named))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search SOPs")
            .navigationTitle("SOPify")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingNewSheet = true } label: {
                            Label("New SOP", systemImage: "plus")
                        }
                        Button { showingNewTempSheet = true } label: {
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
            .navigationDestination(for: Category.self) { cat in
                CategoryDetailView(category: cat, title: cat.name)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self],
                        inMemory: true)
}
