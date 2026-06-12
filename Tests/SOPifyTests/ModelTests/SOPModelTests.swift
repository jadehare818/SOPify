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

    // MARK: - Branching SOP tests

    func testSOPCanBeCreatedAsBranching() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Route decision", type: .branching)
        context.insert(sop)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SOP>())
        XCTAssertEqual(fetched.first?.type, .branching)
    }

    func testStepBranchFieldsDefaultToNil() {
        let step = Step(text: "Normal step", order: 0)
        XCTAssertNil(step.branchQuestion)
        XCTAssertFalse(step.isBranch)
        XCTAssertTrue(step.rejoinAfter)
    }

    func testStepCanBeCreatedAsBranchPoint() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let step = Step(text: "Which way?", order: 0, branchQuestion: "Which way do you go?")
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Step>())
        XCTAssertEqual(fetched.first?.branchQuestion, "Which way do you go?")
        XCTAssertTrue(fetched.first?.isBranch ?? false)
    }

    func testBranchOptionCreation() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let childSOPId = UUID()
        let option = BranchOption(label: "Take the bus", order: 0, targetSOPId: childSOPId)
        context.insert(option)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BranchOption>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.label, "Take the bus")
        XCTAssertEqual(fetched.first?.targetSOPId, childSOPId)
    }

    func testBranchPointWithOptions() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let sop = SOP(name: "Commute", type: .branching)

        // Create branch step
        let branchStep = Step(text: "How to get there?", order: 0, branchQuestion: "How to get there?")

        // Create child SOPs for each option
        let busSOP = SOP(name: "Bus route", type: .checklist)
        busSOP.parentStepId = branchStep.id
        busSOP.steps = [Step(text: "Walk to stop", order: 0), Step(text: "Board bus", order: 1)]

        let bikeSOP = SOP(name: "Bike route", type: .checklist)
        bikeSOP.parentStepId = branchStep.id
        bikeSOP.steps = [Step(text: "Unlock bike", order: 0), Step(text: "Ride", order: 1)]

        // Create options linking to child SOPs
        let opt1 = BranchOption(label: "Bus", order: 0, targetSOPId: busSOP.id)
        opt1.step = branchStep
        let opt2 = BranchOption(label: "Bike", order: 1, targetSOPId: bikeSOP.id)
        opt2.step = branchStep

        sop.steps = [branchStep, Step(text: "Arrive at work", order: 1)]

        context.insert(sop)
        context.insert(busSOP)
        context.insert(bikeSOP)
        context.insert(opt1)
        context.insert(opt2)
        try context.save()

        // Verify structure
        let fetchedSOP = try context.fetch(FetchDescriptor<SOP>(predicate: #Predicate { $0.name == "Commute" }))
        XCTAssertEqual(fetchedSOP.first?.steps.count, 2)

        let fetchedBranch = fetchedSOP.first?.steps.first(where: { $0.isBranch })
        XCTAssertNotNil(fetchedBranch)
        XCTAssertEqual(fetchedBranch?.branchOptions.count, 2)

        let sortedOptions = fetchedBranch!.branchOptions.sorted(by: { $0.order < $1.order })
        XCTAssertEqual(sortedOptions[0].label, "Bus")
        XCTAssertEqual(sortedOptions[1].label, "Bike")

        // Verify child SOPs
        let busChild = try context.fetch(FetchDescriptor<SOP>(predicate: #Predicate { $0.name == "Bus route" }))
        XCTAssertTrue(busChild.first?.isChild ?? false)
        XCTAssertEqual(busChild.first?.steps.count, 2)
    }

    func testRejoinAfterDefaultsToTrue() {
        let step = Step(text: "Branch", order: 0, branchQuestion: "Q?")
        XCTAssertTrue(step.rejoinAfter)
    }

    func testRejoinAfterCanBeDisabled() throws {
        let container = try InMemoryContainer.make()
        let context = ModelContext(container)

        let step = Step(text: "Branch", order: 0, branchQuestion: "Q?", rejoinAfter: false)
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Step>())
        XCTAssertFalse(fetched.first?.rejoinAfter ?? true)
    }
}
