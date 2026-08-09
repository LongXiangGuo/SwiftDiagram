import Foundation

/// Swift type representing a PlantUML script (@startuml ... @enduml)
public struct PlantUMLScript {
    /// textual representation of the script (@startuml ... @enduml)
    public private(set) var text: String = ""

    /// public private(set) var configuration: PlantUMLConfiguration = .default
    private var context: PlantUMLContext

    /// 默认初始化。
    ///
    /// - Parameters:
    ///   - items: 语法结构元素
    ///   - configuration: 配置
    ///   - groupFilter: 非 nil 时只渲染该 group 的元素（单图模式）：不包裹 package、不输出跨组聚合线。
    internal init(items: [SyntaxStructure], configuration: Configuration = .default, groupFilter: String? = nil) {
        context = PlantUMLContext(configuration: configuration)

        let methodStart = Date()

        text = "@startuml"
        // 布局调优在前，用户 skinparamCommands 在后可覆盖（skinparam 后写覆盖先写）
        text.appendAsNewLine(layoutStyling)
        text.appendAsNewLine(defaultStyling)
        text.appendAsNewLine("set namespaceSeparator none")

        let newLine = "\n"
        var mainContent = newLine

        var adjustedItems = items

        if let groupFilter {
            // 单 group 渲染：只保留该组的元素，组内关系自然保留
            adjustedItems = items.filter { $0.groupName == groupFilter }
        }

        if context.configuration.elements.showNestedTypes {
            adjustedItems = adjustedItems.populateNestedTypes()
        }

        adjustedItems = adjustedItems.orderedByProtocolsFirstExtensionsLast()

        // 分组开启时：按 group 稳定排序聚拢同组元素（组内保持原有顺序），
        // 避免同组被协议优先/扩展靠后的排序拆成多段 package。
        // 单 group 渲染（groupFilter 非 nil）时不走此路径。
        let groupsEnabled = groupFilter == nil && !configuration.groupSettings.enabledGroups.isEmpty
        if groupsEnabled {
            adjustedItems = adjustedItems.enumerated()
                .sorted { lhs, rhs in
                    let g1 = lhs.element.groupName ?? ""
                    let g2 = rhs.element.groupName ?? ""
                    return g1 == g2 ? lhs.offset < rhs.offset : g1 < g2
                }
                .map(\.element)
        }

        // 注入「类型名 → 分组」映射，供跨 group 关系裁剪使用
        injectGroupMapping(items: adjustedItems)

        // 分组渲染：按 group 包裹为 PlantUML package
        var lastGroup: String?
        for (index, element) in adjustedItems.enumerated() {
            let elementGroup = element.groupName ?? ""
            if groupsEnabled {
                if elementGroup != lastGroup {
                    if lastGroup != nil, !lastGroup!.isEmpty {
                        mainContent.appendAsNewLine("}")
                    }
                    if !elementGroup.isEmpty {
                        mainContent.appendAsNewLine("package \"\(elementGroup)\" {")
                    }
                    lastGroup = elementGroup
                }
            }
            if let text = processStructureItem(item: element, index: index) {
                mainContent.appendAsNewLine(text)
            }
        }
        if groupsEnabled, let lastGroup, !lastGroup.isEmpty {
            mainContent.appendAsNewLine("}")
        }

        context.collectNestedTypeConnections(items: adjustedItems)

        // 推导关联/组合关系
        deriveRelationships(items: adjustedItems)

        var allConnections = context.connections
        if groupsEnabled {
            allConnections.append(contentsOf: context.groupAggregateLines())
        }

        let definitions = mainContent + newLine + allConnections.joined(separator: newLine) + newLine + context.extnConnections.joined(separator: newLine)

        text.appendAsNewLine(definitions)
        text.appendAsNewLine("@enduml")

        Logger.shared.debug("PlantUML script created in \(Date().timeIntervalSince(methodStart)) seconds")
    }

    /// 构建「类型名 → 分组」映射。键同时包含 `fullName` 与短名，便于关系匹配。
    private mutating func injectGroupMapping(items: [SyntaxStructure]) {
        for item in items {
            if let groupName = item.groupName {
                if let fullName = item.fullName {
                    context.groupForTypeName[fullName] = groupName
                }
                if let name = item.name {
                    context.groupForTypeName[name] = groupName
                }
            }
        }
    }

    /// 遍历所有类型，推导「关联 / 组合」关系并加入连接。
    private mutating func deriveRelationships(items: [SyntaxStructure]) {
        let extractor = DependencyExtractor(items: items)
        for item in items {
            guard item.kind == ElementKind.class || item.kind == ElementKind.struct || item.kind == ElementKind.extension else { continue }
            for dependency in extractor.extract(from: item) {
                context.addDerivedLinking(from: dependency.sourceName, to: dependency.targetName, kind: dependency.kind, item: item)
            }
        }
    }

    /**
      encodes diagram text description according to PlantUML.  See https://plantuml.com/en/text-encoding for more information.

       1. Encoded in UTF-8
       2. Compressed using Deflate algorithm
       3. Reencoded in ASCII using a transformation *close* to base64

     - Returns: encoded diagram text description
     */
    public func encodeText() -> String {
        PlantUMLText(rawValue: text).encodedValue
    }

    /// 布局调优（防止内容过多画布超限被截断）：
    /// - `scale max W*H`：限制逻辑画布，超限整体缩小而非截断；
    /// - `nodesep/ranksep`：控制节点与线间距，避免画布异常膨胀；
    /// - `wrapWidth`：长文本自动换行，避免单个类框横向撑爆。
    internal var layoutStyling: String {
        """
        ' LAYOUT START
        scale max 12000*8000
        skinparam nodesep 30
        skinparam ranksep 40
        skinparam wrapWidth 350
        ' LAYOUT END
        """
    }

    /// default styling block (skinparam commands only)
    internal var defaultStyling: String {
        let skinparamCommands: [String] = context.configuration.skinparamCommands ?? ["skinparam shadow false", "skinparam classWidth 120"]

        if skinparamCommands.isEmpty {
            return ""
        } else {
            return """
            ' STYLE START
            \(skinparamCommands.joined(separator: "\n"))
            ' STYLE END
            """
        }
    }

    mutating func processStructureItem(item: SyntaxStructure, index _: Int) -> String? {
        let processableKinds: [ElementKind] = [.class, .struct, .extension, .enum, .protocol]
        guard let elementKind = item.kind else { return nil }
        guard processableKinds.contains(elementKind) else { return nil }
        return item.plantuml(context: context) ?? nil
    }
}
