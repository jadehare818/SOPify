import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingImportPicker = false
    @State private var showingExportShare = false
    @State private var exportData: Data?
    @State private var importResult: ImportResult?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportAll()
                    } label: {
                        Label("Export All SOPs", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Exports all SOPs, categories, and triggers as a JSON file. One-shot SOPs are excluded.")
                }

                Section {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import from JSON", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Import SOPs from a previously exported JSON file. Duplicates (same ID) are skipped.")
                }
            }
            .navigationTitle("Import / Export")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showingExportShare) {
                if let data = exportData {
                    ShareSheet(data: data, filename: "SOPify-export.json")
                }
            }
            .alert("Import Complete", isPresented: $showingResult) {
                Button("OK") {}
            } message: {
                if let r = importResult {
                    Text("Created \(r.sopsCreated) SOP(s), skipped \(r.sopsSkipped) duplicate(s).\nCategories: \(r.categoriesCreated) new, \(r.categoriesSkipped) existing.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func exportAll() {
        do {
            exportData = try ExportService.exportAll(context: context)
            showingExportShare = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"
                showingError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                importResult = try ImportService.importData(data, context: context)
                showingResult = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Share sheet wrapper

struct ShareSheet: View {
    let data: Data
    let filename: String

    @Environment(\.dismiss) private var dismiss
    @State private var tempURL: URL?

    var body: some View {
        Group {
            if let url = tempURL {
                #if os(iOS)
                ShareSheetUIKit(url: url)
                #else
                VStack(spacing: 16) {
                    Text("Export ready")
                        .font(.headline)
                    Text(filename)
                        .foregroundStyle(.secondary)
                    Button("Save to Desktop") {
                        saveToDesktop(url: url)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Close") { dismiss() }
                }
                .padding(40)
                #endif
            } else {
                ProgressView()
                    .onAppear { writeTempFile() }
            }
        }
    }

    private func writeTempFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        tempURL = url
    }

    #if os(macOS)
    private func saveToDesktop(url: URL) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").appendingPathComponent(filename)
        try? FileManager.default.copyItem(at: url, to: desktop)
        dismiss()
    }
    #endif
}

#if os(iOS)
import UIKit

struct ShareSheetUIKit: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
