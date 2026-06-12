import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newIcon = "folder.fill"
    @State private var notificationsPaused = NotificationService.shared.isPaused

    var body: some View {
        List {
            Section("Categories") {
                ForEach(categories) { cat in
                    HStack {
                        Image(systemName: cat.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30)
                        Text(cat.name)
                        Spacer()
                        Text("\(cat.sops.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }

            Section("Notifications") {
                Toggle("Pause all notifications", isOn: $notificationsPaused)
                    .onChange(of: notificationsPaused) { _, newValue in
                        NotificationService.shared.isPaused = newValue
                        if newValue {
                            NotificationService.shared.cancelAll()
                        }
                    }
            }
        }
        .navigationTitle("Settings")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
        }
        .alert("New Category", isPresented: $showingAdd) {
            TextField("Name", text: $newName)
            Button("Add") { addCategory() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func addCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cat = Category(name: name, icon: newIcon, order: categories.count)
        context.insert(cat)
        try? context.save()
        newName = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(categories[index])
        }
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories.map { $0 }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, cat) in ordered.enumerated() {
            cat.order = i
        }
        try? context.save()
    }
}
