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

    func testSOPCanBeCreatedAsFlow() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Morning routine", type: .flow)
        context.insert(sop)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.first?.type, .flow)
    }

    // MARK: - Nested sub-SOP tests

    func testStepNestedSOPIdDefaultsToNil() {
        let step = Step(text: "Plain step", order: 0)
        XCTAssertNil(step.nestedSOPId)
        XCTAssertFalse(step.isNested)
    }

    func testStepCanBeCreatedWithNestedSOPId() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let childId = UUID()
        let step = Step(text: "Sub-SOP step", order: 0, nestedSOPId: childId)
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Step>())
        XCTAssertEqual(fetched.first?.nestedSOPId, childId)
        XCTAssertTrue(fetched.first?.isNested ?? false)
    }

    func testSOPParentStepIdDefaultsToNil() {
        let sop = SOP(name: "Regular SOP")
        XCTAssertNil(sop.parentStepId)
        XCTAssertFalse(sop.isChild)
    }

    func testSOPCanBeMarkedAsChild() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let parentStepId = UUID()
        let childSOP = SOP(name: "Child SOP")
        childSOP.parentStepId = parentStepId
        context.insert(childSOP)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.first?.parentStepId, parentStepId)
        XCTAssertTrue(fetched.first?.isChild ?? false)
    }

    func testNestedSOPLinkage() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        // Create parent SOP
        let parent = SOP(name: "Swimming", type: .flow)

        // Create child SOP
        let child = SOP(name: "Locker room prep", type: .checklist)

        // Create a step linking to the child
        let nestedStep = Step(text: "Locker room prep", order: 0, nestedSOPId: child.id)
        child.parentStepId = nestedStep.id

        parent.steps = [nestedStep]
        child.steps = [
            Step(text: "Change clothes", order: 0),
            Step(text: "Store bag in locker", order: 1),
        ]

        context.insert(parent)
        context.insert(child)
        try context.save()

        // Verify parent has nested step
        let fetchedParent = try context.fetch(FetchDescriptor<SOP>(predicate: #Predicate { $0.name == "Swimming" }))
        XCTAssertEqual(fetchedParent.first?.steps.count, 1)
        XCTAssertTrue(fetchedParent.first?.steps.first?.isNested ?? false)

        // Verify child is linked
        let childId = fetchedParent.first!.steps.first!.nestedSOPId!
        let fetchedChild = try context.fetch(FetchDescriptor<SOP>(predicate: #Predicate { $0.id == childId }))
        XCTAssertEqual(fetchedChild.first?.name, "Locker room prep")
        XCTAssertEqual(fetchedChild.first?.steps.count, 2)
        XCTAssertTrue(fetchedChild.first?.isChild ?? false)
    }
}
