import Foundation

struct CondaEnv: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    var isActive: Bool
    var pythonVersion: String?
    var sizeString: String?
}

struct CondaPackage: Identifiable, Codable, Hashable {
    var id: String { "\(name)-\(version)-\(buildString)" }
    let name: String
    let version: String
    let buildString: String
    let channel: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case version
        case buildString = "build_string"
        case channel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        
        // Handle channel gracefully (sometimes it's missing or an empty string)
        channel = (try? container.decode(String.self, forKey: .channel)) ?? "unknown"
        
        // Dynamic search for build_string or build
        if let bs = try? container.decode(String.self, forKey: .buildString) {
            buildString = bs
        } else {
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            if let bKey = DynamicCodingKeys(stringValue: "build"),
               let bs = try? dynamicContainer.decode(String.self, forKey: bKey) {
                buildString = bs
            } else if let bKey = DynamicCodingKeys(stringValue: "build"),
                      let bsInt = try? dynamicContainer.decode(Int.self, forKey: bKey) {
                buildString = String(bsInt)
            } else {
                buildString = "n/a"
            }
        }
    }
    
    init(name: String, version: String, buildString: String, channel: String) {
        self.name = name
        self.version = version
        self.buildString = buildString
        self.channel = channel
    }
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    var intValue: Int?
    init?(intValue: Int) {
        return nil
    }
}
