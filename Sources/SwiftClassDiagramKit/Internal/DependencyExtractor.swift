import Foundation

/// 从源码结构推导「关联 / 组合」关系。
///
/// 语义（按用户约定）：
/// - **组合 composition**：属性声明依赖 + 初始化器参数依赖（`A *-- B`）
/// - **关联 association**：方法签名依赖（参数/返回类型，`A --> B`）
///
/// 仅推导图中已知类型（避免链接到 `String`、`Int` 等外部/基础类型），
/// 且受 `RelationshipOptions` 的启用开关与排除名单约束。
struct DependencyExtractor {
    /// 一条推导出的依赖关系
    struct Dependency {
        /// 源类型名（发起依赖的类型，通常为所属类）
        let sourceName: String
        /// 目标类型名（被依赖的类型）
        let targetName: String
        /// 关系类型（组合或关联）
        let kind: RelationshipKind
    }

    /// 已知类型的名字集合（图中出现的类型，用于过滤外部类型）。
    private let knownTypeNames: Set<String>
    private let knownDisplayNames: Set<String>

    init(items: [SyntaxStructure]) {
        var names = Set<String>()
        var displayNames = Set<String>()
        for item in items {
            if let fullName = item.fullName {
                names.insert(fullName)
            }
            if let name = item.name {
                names.insert(name)
                displayNames.insert(name)
            }
            if let displayName = item.displayName {
                displayNames.insert(displayName)
            }
        }
        knownTypeNames = names
        knownDisplayNames = displayNames
    }

    /// 提取单个类型（class/struct/extension）的所有推导依赖。
    /// - Parameter item: 要分析的类型结构
    func extract(from item: SyntaxStructure) -> [Dependency] {
        guard let sourceName = item.fullName ?? item.name else { return [] }
        guard let members = item.substructure else { return [] }

        var dependencies: [Dependency] = []
        var seen = Set<String>()

        func addDependency(target rawType: String, kind: RelationshipKind) {
            for name in resolvedTypeNames(in: rawType) {
                let key = "\(sourceName)|\(name)|\(kind.rawValue)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                guard name != sourceName else { continue } // 排除自引用
                dependencies.append(Dependency(sourceName: sourceName, targetName: name, kind: kind))
            }
        }

        for member in members {
            switch member.kind {
            // 组合：属性声明依赖
            case .varInstance, .varStatic:
                if let type = member.typename {
                    addDependency(target: type, kind: .composition)
                }
            // 组合：初始化器参数依赖
            case .functionConstructor:
                extractParameterTypes(from: member).forEach {
                    addDependency(target: $0, kind: .composition)
                }
            // 关联：方法签名依赖（参数 + 返回类型）
            case .functionMethodInstance, .functionMethodStatic:
                // SourceKit 将 `init` 报为 method.instance（而非 constructor），
                // 需按构造器语义归为组合关系。
                let isInitializer = member.name?.hasPrefix("init") == true
                extractParameterTypes(from: member).forEach {
                    addDependency(target: $0, kind: isInitializer ? .composition : .association)
                }
                if !isInitializer, let returnType = member.typename {
                    addDependency(target: returnType, kind: .association)
                }
            default:
                break
            }
        }

        return dependencies
    }

    /// 从方法/初始化器中提取参数类型名。
    private func extractParameterTypes(from function: SyntaxStructure) -> [String] {
        guard let params = function.substructure else { return [] }
        return params.compactMap { param in
            param.kind == ElementKind.varParameter ? param.typename : nil
        }
    }

    /// 从类型名文本中解析出「图中已知的类型名」。
    /// 处理 `PeerInfo`、`PeerInfo?`、`[PeerInfo]`、`Result<PeerInfo, Error>`、
    /// `(PeerInfo) -> Void` 等形态，仅返回能匹配已知类型的名字。
    private func resolvedTypeNames(in rawType: String) -> [String] {
        var names = Set<String>()
        // 剥离泛型参数、可选/隐式解包、数组、字典、元组、闭包、some/any 关键字
        var cleaned = rawType
        cleaned = cleaned.replacingOccurrences(of: "some ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "any ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "]", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "(", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ")", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "<", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ">", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "->", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "?", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "!", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ",", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "...", with: " ")

        for component in cleaned.split(whereSeparator: { $0.isWhitespace || $0 == ":" }) {
            let token = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, token.first?.isLetter == true || token.first == "_" else { continue }
            guard isKnownType(token) else { continue }
            names.insert(token)
        }
        return Array(names)
    }

    /// 判断类型名是否为图中已知类型（供度量报告等复用，过滤 `String`/`Int` 等外部类型）。
    func isKnownType(_ name: String) -> Bool {
        if knownTypeNames.contains(name) || knownDisplayNames.contains(name) {
            return true
        }
        // 支持模块前缀限定名（如 `CrossNetworkDomain.Frame`）：取其最后一段匹配
        if name.contains("."), let last = name.split(separator: ".").last {
            let tail = String(last)
            return knownDisplayNames.contains(tail)
        }
        return false
    }
}
