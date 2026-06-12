import Foundation

struct SOPExportEnvelope: Codable {
    let version: Int
    let exportedAt: Date
    let categories: [CategoryExport]
    let sops: [SOPExport]
}

struct CategoryExport: Codable {
    let id: UUID
    let name: String
    let icon: String
    let order: Int
}

struct SOPExport: Codable {
    let id: UUID
    let name: String
    let type: String
    let isOneShot: Bool
    let categoryId: UUID?
    let createdAt: Date
    let steps: [StepExport]
    let branchPoints: [BranchPointExport]
    let triggers: [TriggerExport]
}

struct StepExport: Codable {
    let id: UUID
    let text: String
    let order: Int
    let nestedSOP: SOPExport?
}

struct BranchPointExport: Codable {
    let id: UUID
    let question: String
    let order: Int
    let rejoinAfter: Bool
    let options: [BranchOptionExport]
}

struct BranchOptionExport: Codable {
    let id: UUID
    let label: String
    let order: Int
    let targetSOP: SOPExport?
    let actionText: String?
}

struct TriggerExport: Codable {
    let kind: String
    let recurrence: String?
    let hour: Int?
    let minute: Int?
    let weekday: Int?
    let dayOfMonth: Int?
    let predecessorSOPId: UUID?
    let isEnabled: Bool
}
