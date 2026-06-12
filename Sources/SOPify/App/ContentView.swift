import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadRootView()
            } else {
                HomeView()
            }
        }
        .onAppear {
            DefaultSeeder.seedIfNeeded(context: context)
        }
    }
}

// MARK: - iPad Split View

struct iPadRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(DeeplinkRouter.self) private var deeplinkRouter
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \SOP.createdAt, order: .reverse) private var allSOPs: [SOP]

    @State private var selectedSidebar: SidebarItem? = .allSOPs
    @State private var selectedSOP: SOP?
    @State private var showingNewSheet = false
    @State private var showingNewTempSheet = false
    @State private var showingTemplates = false

    enum SidebarItem: Hashable {
        case allSOPs
        case temp
        case category(UUID)
        case uncategorized
        case diary
        case settings
    }

    private var uncategorizedSOPs: [SOP] {
        allSOPs.filter { !$0.isOneShot && $0.category == nil && !$0.isChild }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                Section("SOPs") {
                    Label("All", systemImage: "list.bullet")
                        .tag(SidebarItem.allSOPs)
                    Label("临时", systemImage: "bolt.fill")
                        .tag(SidebarItem.temp)
                }
                Section("Categories") {
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.icon)
                            .tag(SidebarItem.category(cat.id))
                    }
                    if !uncategorizedSOPs.isEmpty {
                        Label("Uncategorized", systemImage: "tray")
                            .tag(SidebarItem.uncategorized)
                    }
                }
                Section {
                    Label("Diary", systemImage: "book")
                        .tag(SidebarItem.diary)
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .tag(SidebarItem.settings)
                }
            }
            .navigationTitle("SOPify")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingNewSheet = true } label: {
                            Label("New SOP", systemImage: "plus")
                        }
                        Button { showingNewTempSheet = true } label: {
                            Label("临时 SOP", systemImage: "bolt")
                        }
                        Button { showingTemplates = true } label: {
                            Label("From Template", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } content: {
            Group {
                switch selectedSidebar {
                case .allSOPs:
                    iPadSOPListView(sops: allSOPs.filter { !$0.isOneShot && !$0.isChild }, title: "All SOPs", selection: $selectedSOP)
                case .temp:
                    iPadSOPListView(sops: allSOPs.filter { $0.isOneShot && !$0.isChild }, title: "临时", selection: $selectedSOP)
                case .category(let id):
                    let cat = categories.first(where: { $0.id == id })
                    iPadSOPListView(sops: allSOPs.filter { $0.category?.id == id && !$0.isOneShot && !$0.isChild }, title: cat?.name ?? "Category", selection: $selectedSOP)
                case .uncategorized:
                    iPadSOPListView(sops: uncategorizedSOPs, title: "Uncategorized", selection: $selectedSOP)
                case .diary:
                    DiaryView()
                case .settings:
                    ManageCategoriesView()
                case nil:
                    ContentUnavailableView("Select a category", systemImage: "sidebar.left", description: Text("Pick from the sidebar."))
                }
            }
        } detail: {
            if let sop = selectedSOP {
                NavigationStack {
                    SOPDetailRouter(sop: sop)
                }
            } else {
                ContentUnavailableView("Select an SOP", systemImage: "checklist", description: Text("Pick an SOP to execute."))
            }
        }
        .sheet(isPresented: $showingNewSheet) {
            SOPEditView()
        }
        .sheet(isPresented: $showingNewTempSheet) {
            SOPEditView(isOneShot: true)
        }
        .sheet(isPresented: $showingTemplates) {
            TemplateBrowserView()
        }
        .onChange(of: deeplinkRouter.pendingSOPId) { _, newId in
            guard let sopId = newId,
                  let sop = allSOPs.first(where: { $0.id == sopId }) else { return }
            deeplinkRouter.pendingSOPId = nil
            selectedSOP = sop
        }
    }
}

// MARK: - iPad SOP List (content column)

private struct iPadSOPListView: View {
    let sops: [SOP]
    let title: String
    @Binding var selection: SOP?

    var body: some View {
        List(sops, selection: $selection) { sop in
            NavigationLink(value: sop) {
                SOPRowView(sop: sop)
            }
            .tag(sop)
        }
        .navigationTitle(title)
    }
}

// MARK: - SOP Detail Router

struct SOPDetailRouter: View {
    let sop: SOP

    var body: some View {
        switch sop.type {
        case .checklist:
            SOPExecutionView(sop: sop)
        case .flow:
            FlowExecutionView(sop: sop)
        case .branching:
            BranchExecutionView(sop: sop)
        }
    }
}
