import Foundation

/// 输出清洗器：把原先 generate_classdagram.sh 中用 sed 完成的文本 hack 内建为可测试的规则。
///
/// 与旧脚本逐条对应：
/// ① 删除编译器合成协议 / 枚举原始值的关联线：`CaseIterable`、`String`、`UInt8`、`Int`、`Bool`、`AnyObject` 等
/// ② 删除幽灵类型残余行：`"@unchecked Sendable"`
///
/// 判定方式：仅处理「链接行」（包含 `--` / `<|--` / `<|..` / `<..`），且链接左侧类型命中
/// 原始值 / 合成协议 / 幽灵类型名单才删除，避免误删 `+foo : AnyObject` 之类的成员行。
/// 多行换行修复已在渲染层根治（`String.collapsingNewlines`），无需再折叠全文。
public enum OutputCleaner {
    /// 枚举原始值 / 编译器合成协议 / 标准库类型（链接行左侧命中即删除）
    private static let primitiveTypeNames: [String] = [
        "String", "Character", "Bool", "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Double", "Float", "CGFloat",
        "Data", "Date", "Array", "Dictionary", "Set", "Optional", "CaseIterable",
        "RawRepresentable", "CustomStringConvertible", "CustomDebugStringConvertible",
        "Identifiable", "Equatable", "Hashable", "Sendable", "Codable", "Decodable", "Encodable",
        "Comparable", "Strideable", "Sequence", "Collection", "BidirectionalCollection",
        "RandomAccessCollection", "MutableCollection", "ExpressibleByStringLiteral",
        "ExpressibleByIntegerLiteral", "ExpressibleByFloatLiteral", "ExpressibleByBooleanLiteral",
        "LosslessStringConvertible", "Error", "LocalizedError", "OptionSet",
    ]

    /// 幽灵类型（编译器合成，图中无对应元素定义）
    private static let ghostTypeNames: [String] = [
        "@unchecked Sendable",
        "AnyObject",
    ]

    /// PlantUML 链接操作符（按长度降序，优先匹配多字符）
    private static let linkOperators = ["<|..", "<|--", "<..", "--"]

    /// 逐行过滤，保留有效行。
    ///
    /// - Parameter script: 未清洗的 PlantUML 脚本
    /// - Returns: 清洗后的 PlantUML 脚本
    public static func clean(_ script: String) -> String {
        script
            .components(separatedBy: "\n")
            .filter { !isGhostLine($0) }
            .joined(separator: "\n")
    }

    private static func isGhostLine(_ line: String) -> Bool {
        guard let operatorRange = firstLinkOperatorRange(in: line) else { return false }
        let leftType = line[..<operatorRange.lowerBound]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\"", with: "")
        return primitiveTypeNames.contains(leftType) || ghostTypeNames.contains(leftType)
    }

    /// 找出行内第一个链接操作符的位置（如不存在返回 nil）
    private static func firstLinkOperatorRange(in line: String) -> Range<String.Index>? {
        var firstRange: Range<String.Index>?
        for op in linkOperators {
            guard let range = line.range(of: op) else { continue }
            if firstRange == nil || range.lowerBound < firstRange!.lowerBound {
                firstRange = range
            }
        }
        return firstRange
    }
}
