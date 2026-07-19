import Foundation

enum ProviderJSON {
    static func object(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    static func string(_ path: String..., in object: [String: Any]) -> String? {
        var value: Any = object
        for component in path {
            guard let dictionary = value as? [String: Any],
                  let next = dictionary[component]
            else { return nil }
            value = next
        }
        return value as? String
    }

    static func bool(_ path: String..., in object: [String: Any]) -> Bool? {
        var value: Any = object
        for component in path {
            guard let dictionary = value as? [String: Any],
                  let next = dictionary[component]
            else { return nil }
            value = next
        }
        return value as? Bool
    }
}
