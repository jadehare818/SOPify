import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        HomeView()
            .onAppear {
                DefaultSeeder.seedIfNeeded(context: context)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self],
                        inMemory: true)
}
