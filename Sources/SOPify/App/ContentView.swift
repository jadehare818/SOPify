import SwiftUI

struct ContentView: View {
    var body: some View {
        SOPListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
}
