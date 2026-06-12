import Foundation

struct SOPTemplate: Codable, Identifiable {
    let name: String
    let type: String
    let category: String
    let steps: [StepTemplate]

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

struct StepTemplate: Codable {
    let text: String
    let nested: SOPTemplate?

    init(text: String, nested: SOPTemplate? = nil) {
        self.text = text
        self.nested = nested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self.text = text
            self.nested = nil
        } else {
            let obj = try StepTemplateObject(from: decoder)
            self.text = obj.text
            self.nested = obj.nested
        }
    }

    func encode(to encoder: Encoder) throws {
        if nested == nil {
            var container = encoder.singleValueContainer()
            try container.encode(text)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(nested, forKey: .nested)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case text, nested
    }
}

private struct StepTemplateObject: Codable {
    let text: String
    let nested: SOPTemplate?
}
