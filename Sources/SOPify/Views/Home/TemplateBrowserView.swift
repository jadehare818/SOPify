import SwiftUI
import SwiftData

struct TemplateBrowserView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]

    private let templates = SOPTemplate.loadBundled()

    private var groupedTemplates: [(String, [SOPTemplate])] {
        let groups = Dictionary(grouping: templates, by: \.category)
        let order = ["生活", "工作", "运动", "心理", "出行"]
        return order.compactMap { key in
            guard let items = groups[key] else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedTemplates, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { template in
                            TemplateRowButton(template: template) {
                                importTemplate(template)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func importTemplate(_ template: SOPTemplate) {
        let sop = TemplateImporter.importTemplate(template, categories: categories, context: context)
        context.insert(sop)
        try? context.save()
        dismiss()
    }
}

struct TemplateRowButton: View {
    let template: SOPTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(template.steps.count) steps · \(template.type)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
