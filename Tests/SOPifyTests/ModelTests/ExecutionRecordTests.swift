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
