# SOPify Phase 1 — Checklist MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a locally-running iOS app that lets the user create, edit, delete, and execute checklist-type SOPs, capture per-step text feedback, and review execution history.

**Architecture:** SwiftUI + SwiftData (local only, no CloudKit yet). Domain entities (`SOP`, `Step`, `ExecutionRecord`, `StepCompletion`) modeled as `@Model` classes. xcodegen used to generate the Xcode project from a YAML spec, so the project stays text-friendly and AI-editable. UI structured as plain SwiftUI Views with `@Environment(\.modelContext)` for persistence; no MVVM layer in v1 — keep it light.

**Tech Stack:** Swift 5.9+, SwiftUI (iOS 17+), SwiftData, XCTest, xcodegen (project generator), Xcode 15+. Target deployment: iPhone (Universal binary so iPad runs too, but no iPad-specific layouts in this phase).

**Out of scope for Phase 1** (deferred to subsequent plans): flow / branching SOP types, nested sub-SOPs, user-defined categories, scheduled / chained triggers, CloudKit sync, JSON import/export, templates, global diary, paste-parser, reorder-by-drag (use up/down buttons in v1).

---

## Prerequisites

Before starting Task 1, verify the dev machine has:

- macOS with Xcode 15.0+ installed (`xcodebuild -version`)
- Homebrew (`brew --version`)
- Free or paid Apple Developer account signed in to Xcode (Xcode → Settings → Accounts) — needed to install on personal device
- Personal iPhone with iOS 17+ (for device testing in final task; simulator works for everything else)

If any are missing, install them before proceeding.

---

## File Structure

After Phase 1 completes, the repo layout will be:

```
~/SOPify/
├── .gitignore
├── README.md
├── project.yml                          # xcodegen spec
├── SOPify.xcodeproj/                    # generated, gitignored
├── docs/                                # design + plans (already exists)
├── Sources/SOPify/
│   ├── App/
│   │   ├── SOPifyApp.swift              # @main entry point, ModelContainer setup
│   │   └── ContentView.swift            # root view (just hosts SOPListView for now)
│   ├── Models/
│   │   ├── SOP.swift                    # @Model: id, name, type, steps, createdAt
│   │   ├── Step.swift                   # @Model: id, text, order, parent SOP
│   │   ├── ExecutionRecord.swift        # @Model: id, sopId, startedAt, finishedAt, completions
│   │   └── StepCompletion.swift         # @Model: id, stepId, completedAt, feedbackText?
│   ├── Views/
│   │   ├── SOPList/
│   │   │   ├── SOPListView.swift        # list of all SOPs
│   │   │   └── SOPRowView.swift         # one row: name + last-execution stats
│   │   ├── SOPEdit/
│   │   │   ├── SOPEditView.swift        # create / edit SOP form
│   │   │   └── StepEditRow.swift        # one editable step row
│   │   ├── Execution/
│   │   │   ├── SOPExecutionView.swift   # checklist execution screen
│   │   │   ├── StepCheckRow.swift       # one checkable step row with current-highlight
│   │   │   └── FeedbackSheet.swift      # half-sheet for typing feedback
│   │   └── History/
│   │       └── SOPHistoryView.swift     # per-SOP execution history list
│   └── Resources/
│       └── Assets.xcassets/             # AppIcon (placeholder), AccentColor
└── Tests/SOPifyTests/
    ├── ModelTests/
    │   ├── SOPModelTests.swift
    │   ├── ExecutionRecordTests.swift
    │   └── StepCompletionTests.swift
    └── TestHelpers/
        └── InMemoryContainer.swift      # spins up an in-memory ModelContainer for tests
```

Each file has one responsibility. Models live in `Models/`, view files are grouped by screen feature, each view file holds one View type.

---

## Task 1: Verify tooling + install xcodegen

**Files:** none modified.

- [ ] **Step 1: Verify Xcode**

Run: `xcodebuild -version`
Expected: prints "Xcode 15.x.x" or higher.

- [ ] **Step 2: Verify Homebrew**

Run: `brew --version`
Expected: prints "Homebrew 4.x.x" or higher.

- [ ] **Step 3: Install xcodegen**

Run: `brew install xcodegen`
Expected: success or "already installed".

- [ ] **Step 4: Verify xcodegen**

Run: `xcodegen --version`
Expected: prints "Version: 2.x.x".

- [ ] **Step 5: No commit**

This task only verifies environment; nothing to commit.

---

## Task 2: Create `.gitignore` and `README.md`

**Files:**
- Create: `~/SOPify/.gitignore`
- Create: `~/SOPify/README.md`

- [ ] **Step 1: Write `.gitignore`**

Create `~/SOPify/.gitignore` with content:

```gitignore
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcodeproj/
*.xcworkspace/
xcuserdata/
*.xcuserstate
*.xcscmblueprint

# Swift Package Manager
.build/
Package.resolved
.swiftpm/

# Tools
.xcodegen/
```

- [ ] **Step 2: Write `README.md`**

Create `~/SOPify/README.md` with content:

```markdown
# SOPify

Personal iOS app for recording and executing SOPs (Standard Operating Procedures).

See [design doc](docs/superpowers/specs/2026-06-12-sopify-design.md) for full spec.

## Build

Requires: Xcode 15+, xcodegen (`brew install xcodegen`).

```bash
xcodegen generate
open SOPify.xcodeproj
```

Then build & run from Xcode (target: iPhone simulator or device).
```

- [ ] **Step 3: Commit**

```bash
cd ~/SOPify
git add .gitignore README.md
git commit -m "chore: add gitignore and readme"
```

---

## Task 3: Create `project.yml` and generate Xcode project

**Files:**
- Create: `~/SOPify/project.yml`

- [ ] **Step 1: Write `project.yml`**

Create `~/SOPify/project.yml` with content:

```yaml
name: SOPify
options:
  bundleIdPrefix: com.jadehare818
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    GENERATE_INFOPLIST_FILE: YES
    INFOPLIST_KEY_UILaunchScreen_Generation: YES
    INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait"
    INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
targets:
  SOPify:
    type: application
    platform: iOS
    sources:
      - path: Sources/SOPify
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jadehare818.SOPify
        TARGETED_DEVICE_FAMILY: "1,2"   # iPhone + iPad
        INFOPLIST_KEY_CFBundleDisplayName: "SOPify"
  SOPifyTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests/SOPifyTests
    dependencies:
      - target: SOPify
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jadehare818.SOPifyTests
schemes:
  SOPify:
    build:
      targets:
        SOPify: all
        SOPifyTests: [test]
    test:
      targets: [SOPifyTests]
```

- [ ] **Step 2: Create source directories so xcodegen has something to scan**

Run:
```bash
mkdir -p ~/SOPify/Sources/SOPify/App
mkdir -p ~/SOPify/Sources/SOPify/Models
mkdir -p ~/SOPify/Sources/SOPify/Views
mkdir -p ~/SOPify/Sources/SOPify/Resources
mkdir -p ~/SOPify/Tests/SOPifyTests/ModelTests
mkdir -p ~/SOPify/Tests/SOPifyTests/TestHelpers
```

- [ ] **Step 3: Add a placeholder Swift file (xcodegen needs at least one source file to compile)**

Create `~/SOPify/Sources/SOPify/App/SOPifyApp.swift` with content:

```swift
import SwiftUI

@main
struct SOPifyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SOPify")
        }
    }
}
```

Create `~/SOPify/Tests/SOPifyTests/SmokeTest.swift` with content:

```swift
import XCTest

final class SmokeTest: XCTestCase {
    func testAlwaysPasses() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Generate Xcode project**

Run:
```bash
cd ~/SOPify && xcodegen generate
```
Expected: prints "⚙️  Generating project..." and "Created project at SOPify.xcodeproj".

- [ ] **Step 5: Build the project from CLI to verify it compiles**

Run:
```bash
cd ~/SOPify && xcodebuild -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build 2>&1 | tail -20
```
Expected: ends with "** BUILD SUCCEEDED **".

- [ ] **Step 6: Run smoke test from CLI**

Run:
```bash
cd ~/SOPify && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: ends with "** TEST SUCCEEDED **".

If "iPhone 15" simulator is not available, run `xcrun simctl list devices available | grep iPhone` and pick any available iPhone simulator name.

- [ ] **Step 7: Commit**

```bash
cd ~/SOPify
git add project.yml Sources Tests
git commit -m "feat: bootstrap Xcode project via xcodegen"
```

---

## Task 4: `Step` SwiftData model + tests

**Files:**
- Create: `~/SOPify/Sources/SOPify/Models/Step.swift`
- Create: `~/SOPify/Tests/SOPifyTests/TestHelpers/InMemoryContainer.swift`
- Create: `~/SOPify/Tests/SOPifyTests/ModelTests/StepCompletionTests.swift` (placeholder for later)

- [ ] **Step 1: Write `InMemoryContainer.swift` test helper**

Create `~/SOPify/Tests/SOPifyTests/TestHelpers/InMemoryContainer.swift`:

```swift
import Foundation
import SwiftData
@testable import SOPify

enum InMemoryContainer {
    /// Spins up a SwiftData container backed by RAM only — tests can mutate freely
    /// without polluting on-disk state, and each test gets a fresh container.
    static func make() throws -> ModelContainer {
        let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

This file references types that don't exist yet — that's OK, they'll be added in Tasks 4, 5, 6, 7 below. The file won't compile alone but will after all four model files are in place. We add the helper now so test code in Task 4 can use it.

- [ ] **Step 2: Write the failing test for `Step`**

Create `~/SOPify/Tests/SOPifyTests/ModelTests/SOPModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import SOPify

final class SOPModelTests: XCTestCase {
    func testStepCanBeCreatedWithTextAndOrder() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)
        let step = Step(text: "Pack laptop", order: 0)
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Step>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "Pack laptop")
        XCTAssertEqual(fetched.first?.order, 0)
    }
}
```

- [ ] **Step 3: Update `project.yml` to regenerate (not needed — Sources path is recursive)**

Skip — xcodegen already includes new files under `Sources/SOPify/` automatically. Just regenerate.

Run: `cd ~/SOPify && xcodegen generate`

- [ ] **Step 4: Run test to verify it fails (Step type doesn't exist)**

Run:
```bash
cd ~/SOPify && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -30
```
Expected: BUILD FAILED with "cannot find 'Step' in scope" or similar.

- [ ] **Step 5: Write minimal `Step.swift`**

Create `~/SOPify/Sources/SOPify/Models/Step.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Step {
    var id: UUID
    var text: String
    var order: Int
    var sop: SOP?

    init(text: String, order: Int) {
        self.id = UUID()
        self.text = text
        self.order = order
    }
}
```

- [ ] **Step 6: Add stub `SOP` so the schema compiles**

Create `~/SOPify/Sources/SOPify/Models/SOP.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SOP {
    var id: UUID
    var name: String
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
```

This is a stub; Task 5 expands it. We need it now so `Step.sop` resolves and `Schema([SOP.self, …])` in `InMemoryContainer` compiles.

- [ ] **Step 7: Add stubs for `ExecutionRecord` and `StepCompletion` for the same reason**

Create `~/SOPify/Sources/SOPify/Models/ExecutionRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ExecutionRecord {
    var id: UUID
    init() { self.id = UUID() }
}
```

Create `~/SOPify/Sources/SOPify/Models/StepCompletion.swift`:

```swift
import Foundation
import SwiftData

@Model
final class StepCompletion {
    var id: UUID
    init() { self.id = UUID() }
}
```

These are stubs; Tasks 6 and 7 expand them.

- [ ] **Step 8: Regenerate project and run test**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: "** TEST SUCCEEDED **".

- [ ] **Step 9: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Models Tests/SOPifyTests
git commit -m "feat(model): add Step entity + in-memory test container"
```

---

## Task 5: Expand `SOP` model + tests

**Files:**
- Modify: `~/SOPify/Sources/SOPify/Models/SOP.swift`
- Modify: `~/SOPify/Tests/SOPifyTests/ModelTests/SOPModelTests.swift`

- [ ] **Step 1: Write the failing test for SOP-with-steps**

Append to `~/SOPify/Tests/SOPifyTests/ModelTests/SOPModelTests.swift` (inside the test class):

```swift
    func testSOPHoldsOrderedSteps() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Morning routine")
        sop.steps = [
            Step(text: "Brush teeth", order: 0),
            Step(text: "Drink water", order: 1),
        ]
        context.insert(sop)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.count, 1)
        let stored = fetched.first!
        XCTAssertEqual(stored.name, "Morning routine")
        XCTAssertEqual(stored.steps.count, 2)
        let sortedTexts = stored.steps.sorted(by: { $0.order < $1.order }).map(\.text)
        XCTAssertEqual(sortedTexts, ["Brush teeth", "Drink water"])
    }

    func testSOPTypeDefaultsToChecklist() {
        let sop = SOP(name: "X")
        XCTAssertEqual(sop.type, SOPType.checklist)
    }
```

- [ ] **Step 2: Run test to verify failure**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: BUILD FAILED with "value of type 'SOP' has no member 'steps'" / "no member 'type'" / "cannot find 'SOPType' in scope".

- [ ] **Step 3: Replace `SOP.swift` with full version**

Replace `~/SOPify/Sources/SOPify/Models/SOP.swift` content with:

```swift
import Foundation
import SwiftData

enum SOPType: String, Codable, CaseIterable {
    case checklist
    // .flow and .branching come in Phase 2/3
}

@Model
final class SOP {
    var id: UUID
    var name: String
    var typeRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.sop)
    var steps: [Step] = []

    var type: SOPType {
        get { SOPType(rawValue: typeRaw) ?? .checklist }
        set { typeRaw = newValue.rawValue }
    }

    init(name: String, type: SOPType = .checklist) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

`typeRaw` is the storage column (SwiftData wants String/primitive); `type` is the typed accessor. SwiftData currently has limited enum support so this two-property pattern is the safest cross-version approach.

- [ ] **Step 4: Run tests, verify pass**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: "** TEST SUCCEEDED **".

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Models/SOP.swift Tests/SOPifyTests/ModelTests/SOPModelTests.swift
git commit -m "feat(model): expand SOP with steps relationship and type enum"
```

---

## Task 6: Expand `StepCompletion` model + tests

**Files:**
- Modify: `~/SOPify/Sources/SOPify/Models/StepCompletion.swift`
- Create: `~/SOPify/Tests/SOPifyTests/ModelTests/StepCompletionTests.swift`

- [ ] **Step 1: Write failing test**

Create `~/SOPify/Tests/SOPifyTests/ModelTests/StepCompletionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import SOPify

final class StepCompletionTests: XCTestCase {
    func testStepCompletionStoresStepIdAndTimestamp() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let stepId = UUID()
        let now = Date()
        let completion = StepCompletion(stepId: stepId, completedAt: now)
        context.insert(completion)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StepCompletion>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.stepId, stepId)
        XCTAssertEqual(fetched.first?.completedAt, now)
        XCTAssertNil(fetched.first?.feedbackText)
    }

    func testStepCompletionAcceptsFeedbackText() {
        let completion = StepCompletion(stepId: UUID(), completedAt: .now)
        completion.feedbackText = "felt sluggish today"
        XCTAssertEqual(completion.feedbackText, "felt sluggish today")
    }
}
```

- [ ] **Step 2: Run test, verify failure**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: BUILD FAILED — `StepCompletion.init(stepId:completedAt:)` does not exist (current stub only has `init()`).

- [ ] **Step 3: Replace `StepCompletion.swift` with full version**

Replace `~/SOPify/Sources/SOPify/Models/StepCompletion.swift` content with:

```swift
import Foundation
import SwiftData

@Model
final class StepCompletion {
    var id: UUID
    var stepId: UUID
    var completedAt: Date
    var feedbackText: String?
    var record: ExecutionRecord?

    init(stepId: UUID, completedAt: Date, feedbackText: String? = nil) {
        self.id = UUID()
        self.stepId = stepId
        self.completedAt = completedAt
        self.feedbackText = feedbackText
    }
}
```

- [ ] **Step 4: Run test, verify pass**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: "** TEST SUCCEEDED **".

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Models/StepCompletion.swift Tests/SOPifyTests/ModelTests/StepCompletionTests.swift
git commit -m "feat(model): expand StepCompletion with stepId, timestamp, feedback"
```

---

## Task 7: Expand `ExecutionRecord` model + tests

**Files:**
- Modify: `~/SOPify/Sources/SOPify/Models/ExecutionRecord.swift`
- Create: `~/SOPify/Tests/SOPifyTests/ModelTests/ExecutionRecordTests.swift`

- [ ] **Step 1: Write failing test**

Create `~/SOPify/Tests/SOPifyTests/ModelTests/ExecutionRecordTests.swift`:

```swift
import XCTest
import SwiftData
@testable import SOPify

final class ExecutionRecordTests: XCTestCase {
    func testRecordTracksSopAndStartTime() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Pack")
        context.insert(sop)
        let started = Date()
        let record = ExecutionRecord(sop: sop, startedAt: started)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ExecutionRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sop?.name, "Pack")
        XCTAssertEqual(fetched.first?.startedAt, started)
        XCTAssertNil(fetched.first?.finishedAt)
        XCTAssertEqual(fetched.first?.completions.count, 0)
    }

    func testFinishingRecordSetsFinishedAt() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Pack")
        context.insert(sop)
        let record = ExecutionRecord(sop: sop, startedAt: .now)
        context.insert(record)

        let finished = Date(timeIntervalSinceNow: 60)
        record.finishedAt = finished
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ExecutionRecord>())
        XCTAssertEqual(fetched.first?.finishedAt, finished)
    }

    func testRecordHoldsStepCompletions() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Pack")
        context.insert(sop)
        let record = ExecutionRecord(sop: sop, startedAt: .now)
        context.insert(record)

        let completion = StepCompletion(stepId: UUID(), completedAt: .now)
        completion.record = record
        context.insert(completion)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ExecutionRecord>())
        XCTAssertEqual(fetched.first?.completions.count, 1)
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: BUILD FAILED — `ExecutionRecord.init(sop:startedAt:)` and `.completions`, `.startedAt` don't exist.

- [ ] **Step 3: Replace `ExecutionRecord.swift`**

Replace `~/SOPify/Sources/SOPify/Models/ExecutionRecord.swift` with:

```swift
import Foundation
import SwiftData

@Model
final class ExecutionRecord {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var sop: SOP?

    @Relationship(deleteRule: .cascade, inverse: \StepCompletion.record)
    var completions: [StepCompletion] = []

    init(sop: SOP, startedAt: Date) {
        self.id = UUID()
        self.sop = sop
        self.startedAt = startedAt
    }
}
```

- [ ] **Step 4: Run, verify pass**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild test -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" 2>&1 | tail -20
```
Expected: "** TEST SUCCEEDED **".

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Models/ExecutionRecord.swift Tests/SOPifyTests/ModelTests/ExecutionRecordTests.swift
git commit -m "feat(model): expand ExecutionRecord with sop ref, timestamps, completions"
```

---

## Task 8: Wire `ModelContainer` into the app entry point + remove placeholder

**Files:**
- Modify: `~/SOPify/Sources/SOPify/App/SOPifyApp.swift`
- Create: `~/SOPify/Sources/SOPify/App/ContentView.swift`

- [ ] **Step 1: Replace `SOPifyApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct SOPifyApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Create `ContentView.swift` (placeholder pointing to SOPListView, which we add next task)**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        // Replaced with SOPListView in Task 9
        Text("SOPify – list view coming next")
            .padding()
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
cd ~/SOPify && xcodegen generate && xcodebuild -project SOPify.xcodeproj -scheme SOPify -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -10
```
Expected: "** BUILD SUCCEEDED **".

- [ ] **Step 4: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/App
git commit -m "feat(app): wire SwiftData ModelContainer into App entry"
```

---

## Task 9: `SOPListView` — read all SOPs, navigate to edit/execute

**Files:**
- Create: `~/SOPify/Sources/SOPify/Views/SOPList/SOPListView.swift`
- Create: `~/SOPify/Sources/SOPify/Views/SOPList/SOPRowView.swift`
- Modify: `~/SOPify/Sources/SOPify/App/ContentView.swift`

- [ ] **Step 1: Create `SOPRowView.swift`**

```swift
import SwiftUI

struct SOPRowView: View {
    let sop: SOP

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sop.name)
                .font(.headline)
            Text("\(sop.steps.count) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sop = SOP(name: "Morning routine")
    sop.steps = [Step(text: "Brush teeth", order: 0), Step(text: "Drink water", order: 1)]
    return SOPRowView(sop: sop).padding()
}
```

- [ ] **Step 2: Create `SOPListView.swift`**

```swift
import SwiftUI
import SwiftData

struct SOPListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SOP.createdAt, order: .reverse) private var sops: [SOP]
    @State private var showingNewSheet = false

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
                    }
                    .onDelete(perform: delete)
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
                // Replaced with SOPEditView in Task 10
                Text("New SOP form — Task 10")
            }
            .navigationDestination(for: SOP.self) { sop in
                // Replaced with SOPExecutionView in Task 12
                Text("Execute \(sop.name) — Task 12")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sops[index])
        }
        try? context.save()
    }
}

#Preview {
    SOPListView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
}
```

- [ ] **Step 3: Replace `ContentView.swift`**

```swift
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
```

- [ ] **Step 4: Build & launch in simulator manually for visual check**

Run:
```bash
cd ~/SOPify && xcodegen generate
open SOPify.xcodeproj
```

In Xcode: pick "iPhone 15" simulator, ⌘R to run. Expect: "No SOPs yet" empty state. Tap +, the placeholder text "New SOP form — Task 10" appears in a sheet. Close sheet. ✅

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/SOPList Sources/SOPify/App/ContentView.swift
git commit -m "feat(ui): SOPListView with empty state, swipe-to-delete, navigation skeleton"
```

---

## Task 10: `SOPEditView` — create + edit SOPs with text steps

**Files:**
- Create: `~/SOPify/Sources/SOPify/Views/SOPEdit/SOPEditView.swift`
- Create: `~/SOPify/Sources/SOPify/Views/SOPEdit/StepEditRow.swift`
- Modify: `~/SOPify/Sources/SOPify/Views/SOPList/SOPListView.swift` (wire sheet to real view)

- [ ] **Step 1: Create `StepEditRow.swift`**

```swift
import SwiftUI

struct StepEditRow: View {
    @Binding var text: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Step", text: $text, axis: .vertical)
                .lineLimit(1...4)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    StepEditRow(text: .constant("Pack laptop"), onDelete: {})
        .padding()
}
```

- [ ] **Step 2: Create `SOPEditView.swift`**

```swift
import SwiftUI
import SwiftData

struct SOPEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing SOP to edit, or nil to create a new one.
    let editing: SOP?

    @State private var name: String = ""
    @State private var stepTexts: [String] = [""]

    init(editing: SOP? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        let texts = editing?.steps
            .sorted(by: { $0.order < $1.order })
            .map(\.text)
        _stepTexts = State(initialValue: texts?.isEmpty == false ? texts! : [""])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Pack for swim", text: $name)
                }

                Section("Steps") {
                    ForEach(stepTexts.indices, id: \.self) { index in
                        StepEditRow(text: $stepTexts[index]) {
                            stepTexts.remove(at: index)
                            if stepTexts.isEmpty { stepTexts = [""] }
                        }
                    }
                    Button {
                        stepTexts.append("")
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(editing == nil ? "New SOP" : "Edit SOP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        stepTexts.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let nonEmptySteps = stepTexts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing = editing {
            existing.name = trimmedName
            existing.updatedAt = .now
            // Drop old steps; cascade delete via relationship
            for step in existing.steps {
                context.delete(step)
            }
            existing.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
        } else {
            let sop = SOP(name: trimmedName)
            sop.steps = nonEmptySteps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
            context.insert(sop)
        }
        try? context.save()
        dismiss()
    }
}

#Preview("New") {
    SOPEditView()
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
}
```

- [ ] **Step 3: Wire the sheet in `SOPListView.swift`**

In `SOPListView.swift`, replace the `.sheet(isPresented: $showingNewSheet) { ... }` block with:

```swift
            .sheet(isPresented: $showingNewSheet) {
                SOPEditView()
            }
```

- [ ] **Step 4: Add edit-on-tap (later — for now Task 9 navigates to execute, edit is via separate gesture)**

Defer edit entry-point UX to Task 11 (where we add a swipe-to-edit action). For now, only "create new" works through the + button.

- [ ] **Step 5: Build and manually verify in simulator**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

Open Xcode, ⌘R. Tap +, type a name "Test", add 2 steps, save. Verify the row appears in the list with "2 steps" caption. ✅

- [ ] **Step 6: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/SOPEdit Sources/SOPify/Views/SOPList/SOPListView.swift
git commit -m "feat(ui): SOPEditView for creating/editing checklist SOPs"
```

---

## Task 11: Swipe-to-edit on the list row + delete confirmation

**Files:**
- Modify: `~/SOPify/Sources/SOPify/Views/SOPList/SOPListView.swift`

- [ ] **Step 1: Replace the `ForEach` block in `SOPListView.swift`**

Replace the existing `ForEach` and `.onDelete` block with:

```swift
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
```

- [ ] **Step 2: Add `@State private var editTarget: SOP?` next to the other state vars**

In `SOPListView.swift`, near the top of the struct add:

```swift
    @State private var editTarget: SOP?
```

And add this modifier next to the existing `.sheet`:

```swift
            .sheet(item: $editTarget) { sop in
                SOPEditView(editing: sop)
            }
```

- [ ] **Step 3: Remove the now-unused `delete(at:)` function**

Delete the `private func delete(at offsets: IndexSet) { ... }` block from `SOPListView.swift`.

- [ ] **Step 4: Build and manually verify**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

In Xcode ⌘R: swipe a row left, tap "Edit", change name, save. Confirm name updates. Swipe again, tap "Delete", confirm row disappears. ✅

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/SOPList/SOPListView.swift
git commit -m "feat(ui): swipe actions for edit and delete on SOP rows"
```

---

## Task 12: `SOPExecutionView` — checklist execution screen

**Files:**
- Create: `~/SOPify/Sources/SOPify/Views/Execution/SOPExecutionView.swift`
- Create: `~/SOPify/Sources/SOPify/Views/Execution/StepCheckRow.swift`
- Modify: `~/SOPify/Sources/SOPify/Views/SOPList/SOPListView.swift` (wire navigation destination)

- [ ] **Step 1: Create `StepCheckRow.swift`**

```swift
import SwiftUI

struct StepCheckRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(isCurrent ? .system(size: 32) : .system(size: 24))
                    .foregroundStyle(isCompleted ? .green : (isCurrent ? .accentColor : .secondary))
            }
            .buttonStyle(.plain)

            Text(step.text)
                .font(isCurrent ? .title3.weight(.semibold) : .body)
                .foregroundStyle(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)

            Spacer()
        }
        .padding(.vertical, isCurrent ? 12 : 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}

#Preview {
    let step = Step(text: "Pack swim trunks", order: 0)
    return VStack(spacing: 8) {
        StepCheckRow(step: step, isCompleted: true, isCurrent: false, onToggle: {})
        StepCheckRow(step: step, isCompleted: false, isCurrent: true, onToggle: {})
        StepCheckRow(step: step, isCompleted: false, isCurrent: false, onToggle: {})
    }.padding()
}
```

- [ ] **Step 2: Create `SOPExecutionView.swift`**

```swift
import SwiftUI
import SwiftData

struct SOPExecutionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP

    @State private var record: ExecutionRecord?
    @State private var completedStepIDs: Set<UUID> = []

    private var orderedSteps: [Step] {
        sop.steps.sorted(by: { $0.order < $1.order })
    }

    private var currentStepID: UUID? {
        orderedSteps.first(where: { !completedStepIDs.contains($0.id) })?.id
    }

    private var isAllDone: Bool {
        !orderedSteps.isEmpty && completedStepIDs.count == orderedSteps.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(orderedSteps) { step in
                    StepCheckRow(
                        step: step,
                        isCompleted: completedStepIDs.contains(step.id),
                        isCurrent: step.id == currentStepID
                    ) {
                        toggle(step)
                    }
                }
                if isAllDone {
                    Button {
                        finish()
                    } label: {
                        Label("Mark complete", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
            }
            .padding()
        }
        .navigationTitle(sop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureRecord() }
    }

    private func ensureRecord() {
        guard record == nil else { return }
        let r = ExecutionRecord(sop: sop, startedAt: .now)
        context.insert(r)
        try? context.save()
        record = r
    }

    private func toggle(_ step: Step) {
        guard let record else { return }
        if completedStepIDs.contains(step.id) {
            completedStepIDs.remove(step.id)
            // Remove most recent completion for this step
            if let latest = record.completions
                .filter({ $0.stepId == step.id })
                .sorted(by: { $0.completedAt > $1.completedAt })
                .first {
                context.delete(latest)
            }
        } else {
            completedStepIDs.insert(step.id)
            let completion = StepCompletion(stepId: step.id, completedAt: .now)
            completion.record = record
            context.insert(completion)
        }
        try? context.save()
    }

    private func finish() {
        record?.finishedAt = .now
        try? context.save()
        dismiss()
    }
}

#Preview {
    let sop = SOP(name: "Pack for swim")
    sop.steps = [
        Step(text: "Swim trunks", order: 0),
        Step(text: "Goggles", order: 1),
        Step(text: "Towel", order: 2),
    ]
    return NavigationStack {
        SOPExecutionView(sop: sop)
    }
    .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                    inMemory: true)
}
```

- [ ] **Step 3: Wire the navigationDestination in `SOPListView.swift`**

In `SOPListView.swift`, replace the placeholder `.navigationDestination(for: SOP.self) { sop in Text("...") }` block with:

```swift
            .navigationDestination(for: SOP.self) { sop in
                SOPExecutionView(sop: sop)
            }
```

- [ ] **Step 4: Build and manually verify**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

In Xcode ⌘R: tap an SOP, see the steps, current one highlighted (large + tinted background). Tap circle → check (green, strikethrough). Next step becomes current. After all checked, "Mark complete" button appears. Tap → returns to list. ✅

- [ ] **Step 5: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/Execution Sources/SOPify/Views/SOPList/SOPListView.swift
git commit -m "feat(ui): SOPExecutionView with checklist mode and current-step highlight"
```

---

## Task 13: `FeedbackSheet` — text feedback per step

**Files:**
- Create: `~/SOPify/Sources/SOPify/Views/Execution/FeedbackSheet.swift`
- Modify: `~/SOPify/Sources/SOPify/Views/Execution/SOPExecutionView.swift`

- [ ] **Step 1: Create `FeedbackSheet.swift`**

```swift
import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    let stepText: String
    @Binding var draft: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("On step")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stepText)
                    .font(.headline)

                TextEditor(text: $draft)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    FeedbackSheet(stepText: "Drink water", draft: .constant(""), onSave: { _ in })
}
```

- [ ] **Step 2: Add feedback button + sheet wiring in `SOPExecutionView.swift`**

Add the following state vars near `completedStepIDs`:

```swift
    @State private var showingFeedback = false
    @State private var feedbackDraft = ""
```

Add this `toolbar` modifier at the same level as `.navigationTitle(sop.name)`:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    feedbackDraft = ""
                    showingFeedback = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(currentStepID == nil)
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let id = currentStepID, let step = orderedSteps.first(where: { $0.id == id }) {
                FeedbackSheet(stepText: step.text, draft: $feedbackDraft) { text in
                    saveFeedback(text, forStepID: id)
                }
            }
        }
```

Add the `saveFeedback` method inside the struct:

```swift
    private func saveFeedback(_ text: String, forStepID stepID: UUID) {
        guard let record else { return }
        // Attach feedback to most recent completion of this step (if any), else create a new one
        if let latest = record.completions
            .filter({ $0.stepId == stepID })
            .sorted(by: { $0.completedAt > $1.completedAt })
            .first {
            latest.feedbackText = text
        } else {
            let completion = StepCompletion(stepId: stepID, completedAt: .now, feedbackText: text)
            completion.record = record
            context.insert(completion)
        }
        try? context.save()
    }
```

- [ ] **Step 3: Build & verify**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

In Xcode ⌘R: enter execution, tap pencil icon top-right, type something, save. Sheet closes. (Visible verification of saved feedback comes in Task 14.) ✅

- [ ] **Step 4: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/Execution
git commit -m "feat(ui): feedback sheet attached to current step"
```

---

## Task 14: `SOPHistoryView` — per-SOP execution history

**Files:**
- Create: `~/SOPify/Sources/SOPify/Views/History/SOPHistoryView.swift`
- Modify: `~/SOPify/Sources/SOPify/Views/Execution/SOPExecutionView.swift` (add toolbar item linking to history)

- [ ] **Step 1: Create `SOPHistoryView.swift`**

```swift
import SwiftUI
import SwiftData

struct SOPHistoryView: View {
    let sop: SOP

    @Query private var allRecords: [ExecutionRecord]

    init(sop: SOP) {
        self.sop = sop
        let sopID = sop.id
        let predicate = #Predicate<ExecutionRecord> { $0.sop?.id == sopID }
        _allRecords = Query(filter: predicate, sort: \ExecutionRecord.startedAt, order: .reverse)
    }

    var body: some View {
        List {
            if allRecords.isEmpty {
                ContentUnavailableView("No runs yet",
                                       systemImage: "clock",
                                       description: Text("Execute this SOP to log a run."))
            } else {
                ForEach(allRecords) { record in
                    NavigationLink(value: record) {
                        recordRow(record)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ExecutionRecord.self) { record in
            recordDetail(record)
        }
    }

    @ViewBuilder
    private func recordRow(_ record: ExecutionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.headline)
            HStack {
                if let finished = record.finishedAt {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(finished.timeIntervalSince(record.startedAt).formattedDuration())
                } else {
                    Label("Incomplete", systemImage: "circle.dashed")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("\(record.completions.count) steps")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func recordDetail(_ record: ExecutionRecord) -> some View {
        List {
            Section("Started") {
                Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
            }
            if let finished = record.finishedAt {
                Section("Finished") {
                    Text(finished.formatted(date: .abbreviated, time: .standard))
                }
            }
            Section("Step completions") {
                let sorted = record.completions.sorted(by: { $0.completedAt < $1.completedAt })
                if sorted.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stepText(for: c.stepId))
                            Text(c.completedAt.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let fb = c.feedbackText, !fb.isEmpty {
                                Text(fb)
                                    .font(.callout)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Run details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepText(for stepID: UUID) -> String {
        sop.steps.first(where: { $0.id == stepID })?.text ?? "(unknown step)"
    }
}

private extension TimeInterval {
    func formattedDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? ""
    }
}
```

- [ ] **Step 2: Add a "History" button to `SOPExecutionView`'s toolbar**

In `SOPExecutionView.swift`, replace the existing `.toolbar { ... }` block with:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SOPHistoryView(sop: sop)
                } label: {
                    Image(systemName: "clock")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    feedbackDraft = ""
                    showingFeedback = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(currentStepID == nil)
            }
        }
```

- [ ] **Step 3: Build & verify**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

In Xcode ⌘R: execute an SOP, tap clock icon top-right, see history entries (current run shows as "Incomplete" until you tap Mark complete). Tap a history entry to see details + feedback if any. ✅

- [ ] **Step 4: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/History Sources/SOPify/Views/Execution/SOPExecutionView.swift
git commit -m "feat(ui): per-SOP execution history view with run details"
```

---

## Task 15: SOP row stats — show last execution timestamp + run count

**Files:**
- Modify: `~/SOPify/Sources/SOPify/Views/SOPList/SOPRowView.swift`

- [ ] **Step 1: Replace `SOPRowView.swift`**

```swift
import SwiftUI
import SwiftData

struct SOPRowView: View {
    let sop: SOP

    @Query private var records: [ExecutionRecord]

    init(sop: SOP) {
        self.sop = sop
        let sopID = sop.id
        let predicate = #Predicate<ExecutionRecord> {
            $0.sop?.id == sopID && $0.finishedAt != nil
        }
        _records = Query(filter: predicate, sort: \ExecutionRecord.finishedAt, order: .reverse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sop.name)
                .font(.headline)
            HStack {
                Text("\(sop.steps.count) steps")
                if let last = records.first?.finishedAt {
                    Text("•")
                    Text("Last: \(last, format: .relative(presentation: .named))")
                }
                if !records.isEmpty {
                    Text("•")
                    Text("\(records.count) run\(records.count == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SOPRowView(sop: SOP(name: "Morning routine"))
        .modelContainer(for: [SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self],
                        inMemory: true)
        .padding()
}
```

- [ ] **Step 2: Build & verify**

Run:
```bash
cd ~/SOPify && xcodegen generate
```

In Xcode ⌘R: complete an SOP, return to list, see "Last: 1 minute ago • 1 run" caption. ✅

- [ ] **Step 3: Commit**

```bash
cd ~/SOPify
git add Sources/SOPify/Views/SOPList/SOPRowView.swift
git commit -m "feat(ui): SOP row shows last run time and total run count"
```

---

## Task 16: Run on personal iPhone

**Files:** none modified.

This task is manual — install on the user's actual phone so the app is real and usable. Skip for now if no device is available; the app is fully testable in simulator.

- [ ] **Step 1: Plug iPhone into Mac with USB cable. Trust the computer when prompted.**

- [ ] **Step 2: In Xcode → Project navigator → SOPify target → Signing & Capabilities, set Team to your personal Apple ID team.**

If the team list is empty: Xcode → Settings → Accounts → + → Apple ID → sign in with your personal Apple ID. Then return to Signing & Capabilities and pick your name as Team.

- [ ] **Step 3: At the top of the Xcode window, choose your iPhone as the run destination (not a simulator).**

- [ ] **Step 4: ⌘R to build and install.**

First time: iPhone will refuse to launch with "Untrusted Developer". Open Settings → General → VPN & Device Management → tap your developer profile → Trust.

Re-launch from the home screen.

- [ ] **Step 5: Smoke test on device**

Create one SOP, execute, complete, write feedback, view history. Confirm everything works.

- [ ] **Step 6: No commit**

This task only configures Xcode signing; nothing changes in source.

> ⚠️ **Note**: Free Apple ID provisioning expires after 7 days, requiring re-build to keep the app on phone. Paid Apple Developer Program ($99/yr) extends to 1 year and is needed for CloudKit (Phase 4). For Phase 1, free is fine.

---

## Phase 1 Done. Verify acceptance criteria:

- [ ] App launches, shows empty state
- [ ] Can create a checklist SOP with name + steps
- [ ] Can edit existing SOP via swipe → Edit
- [ ] Can delete SOP via swipe → Delete
- [ ] Can execute an SOP: see all steps, current one highlighted, tap to toggle
- [ ] Tapping completed step un-toggles it (deletes its StepCompletion)
- [ ] When all steps done, "Mark complete" button appears; tapping returns to list and timestamps the record
- [ ] Feedback button on execution screen saves text attached to current step
- [ ] History button on execution screen shows all past runs of this SOP
- [ ] Tapping a history entry shows step-by-step completion details with feedback
- [ ] SOP list row shows "N steps • Last: X ago • N runs"
- [ ] All model unit tests pass (`xcodebuild test ...`)
- [ ] (Optional) App runs on personal iPhone

Once all checked, Phase 1 is shippable. Proceed to Phase 2 plan (flow type + nesting + categories).

---

## Notes for the implementer

- **xcodegen regen timing**: Run `xcodegen generate` after adding new files. Modifying existing files doesn't need regen.
- **SwiftData @Model recursion (Phase 2 concern, not now)**: Phase 1 has no nested SOPs, so no recursion issue. Phase 2 will hit it; flagged in design doc §12.
- **Why no MVVM**: SwiftUI's `@Environment(\.modelContext)` + `@Query` already handles state cleanly for this scale. Adding ViewModels is overhead for a personal app.
- **Why no UI tests**: SwiftUI UI tests are flaky and slow to write; the cost-benefit doesn't pencil out at this scale. Manual smoke testing in simulator is the trade.
- **Trim names/steps**: `.trimmingCharacters(in: .whitespaces)` is applied at save time so blank-only inputs don't sneak in.
- **No undo**: deleting an SOP is permanent in v1. If this becomes painful, add `@Environment(\.undoManager)` later.
