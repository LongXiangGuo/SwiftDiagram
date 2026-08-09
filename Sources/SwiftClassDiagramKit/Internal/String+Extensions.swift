import Foundation

internal extension String {
    mutating func appendAsNewLine(_ content: String) {
        append("\n\(content)")
    }
}

internal extension String {
    /// example: "Hello<World>".getAngleBracketsWithContent() returns  "Hello"
    func removeAngleBracketsWithContent() -> String {
        replacingOccurrences(of: "\\<.*\\>", with: "", options: .regularExpression)
    }

    /// example: "Hello<World>".getAngleBracketsWithContent() returns  "<World>"
    func getAngleBracketsWithContent() -> String? {
        do {
            let regex = try NSRegularExpression(pattern: "\\<.*\\>")
            let results = regex.matches(in: self,
                                        range: NSRange(startIndex..., in: self))
            let result = results.map {
                String(self[Range($0.range, in: self)!])
            }

            return result.first
        } catch {
            print("invalid regex: \(error.localizedDescription)")
            return nil
        }
    }
}

internal extension String {
    func isMatching(searchPattern: String) -> Bool {
        let pattern = "^\(searchPattern)$"
            .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
            .replacingOccurrences(of: "?", with: "[^/]")
            .replacingOccurrences(of: "**/", with: "(.+/)?")
            .replacingOccurrences(of: "**", with: ".+")
            .replacingOccurrences(of: "*", with: "([^/]+)?")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return true }
        return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)) != nil
    }
}

internal extension String {
    /// 折叠内部换行/连续空白为单个空格，防止多行函数签名破坏单行 PlantUML 语法。
    /// 这是对 generate_classdagram.sh 中 `tr '\n' ' '` hack 的根治（渲染层内建）。
    func collapsingNewlines() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
