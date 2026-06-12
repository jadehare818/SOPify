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

    func testIsOneShotDefaultsToFalse() {
        let sop = SOP(name: "Regular")
        XCTAssertFalse(sop.isOneShot)
    }

    func testIsOneShotCanBeSetToTrue() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Temp task", isOneShot: true)
        context.insert(sop)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.first?.isOneShot, true)
    }

    func testCategoryHoldsSOPs() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let cat = SOPify.Category(name: "生活", icon: "house.fill", order: 0)
        context.insert(cat)

        let sop = SOP(name: "Morning routine")
        sop.category = cat
        context.insert(sop)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOPify.Category>())
        XCTAssertEqual(fetched.first?.sops.count, 1)
        XCTAssertEqual(fetched.first?.sops.first?.name, "Morning routine")
    }

    func testDeleteCategoryNullifiesSOPs() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let cat = SOPify.Category(name: "Work", icon: "briefcase.fill", order: 0)
        context.insert(cat)

        let sop = SOP(name: "Meeting prep")
        sop.category = cat
        context.insert(sop)
        try context.save()

        context.delete(cat)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched.first?.category)
    }
}
