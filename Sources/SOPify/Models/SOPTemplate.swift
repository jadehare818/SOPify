import Foundation

struct SOPTemplate: Codable, Identifiable {
    let name: String
    let type: String
    let category: String
    let steps: [String]

    var id: String { name }

    var sopType: SOPType {
        SOPType(rawValue: type) ?? .checklist
    }

    static func loadBundled() -> [SOPTemplate] {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let templates = try? JSONDecoder().decode([SOPTemplate].self, from: data) else {
            return []
        }
        return templates
    }
}
