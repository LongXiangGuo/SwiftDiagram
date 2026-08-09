import Foundation

/// 从源码 AST 结构收集设计复杂度与模块耦合度量。
///
/// 只统计图内顶层类型（类图绘制范围一致），嵌套类型归入其所属顶层类型的复杂度。
enum MetricsCollector {
    // MARK: - 入口

    /// 收集完整度量报告。
    /// - Parameters:
    ///   - items: 各源文件的顶层类型结构（已注入 `filePath` / `resolvedRule`）
    ///   - fileCount: 参与分析的源文件数
    static func collect(items: [SyntaxStructure], fileCount: Int) -> MetricsReport {
        let extractor = DependencyExtractor(items: items)

        // 1) 每个类型的复杂度与出边关系
        var classMetrics: [ClassMetrics] = []
        for item in items {
            guard let metric = metric(for: item, extractor: extractor, allItems: items) else { continue }
            classMetrics.append(metric)
        }

        // 2) 入边关系（翻转出边）
        classMetrics = attachIncoming(to: classMetrics)

        // 3) 模块维度统计
        let moduleNames = moduleOrder(in: classMetrics)
        let modules = moduleNames.compactMap { moduleMetrics(named: $0, in: classMetrics) }
        let matrix = couplingMatrix(modules: modules, allClasses: classMetrics)

        // 4) 复杂度排名
        let ranking = classMetrics.sorted { $0.complexityScore > $1.complexityScore }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        return MetricsReport(
            generatedAt: timestamp,
            totalTypeCount: classMetrics.count,
            totalFileCount: fileCount,
            modules: modules,
            couplingMatrix: matrix,
            classes: classMetrics,
            complexityRanking: ranking
        )
    }

    // MARK: - 单类型度量

    private static func metric(for item: SyntaxStructure, extractor: DependencyExtractor, allItems: [SyntaxStructure]) -> ClassMetrics? {
        guard let typeName = item.fullName ?? item.name, let kind = item.kind else { return nil }

        let members = item.substructure ?? []
        let propertyCount = members.filter { $0.kind == .varInstance || $0.kind == .varStatic }.count
        let methodCount = members.filter {
            $0.kind == .functionMethodInstance || $0.kind == .functionMethodStatic || $0.kind == .functionConstructor
        }.count
        let privateCount = members.filter { member in
            isMember(member) && isPrivate(member.accessibility)
        }.count
        let publicCount = members.filter { member in
            isMember(member) && isPublic(member.accessibility)
        }.count
        let internalCount = members.filter { member in
            isMember(member) && !isPrivate(member.accessibility) && !isPublic(member.accessibility)
        }.count
        let staticCount = members.filter { $0.kind == .varStatic || $0.kind == .functionMethodStatic }.count
        let inheritedCount = item.inheritedTypes?.count ?? 0
        let genericCount = members.filter { $0.kind == .genericTypeParam }.count

        // 扩展数：同名扩展声明的数量（item 本身是扩展时不重复计入）
        let extensionCount = item.kind == .extension
            ? 1
            : allItems.filter { $0.kind == .extension && $0.fullName == typeName }.count

        // 出边关系：组合/关联（推导）+ 继承/实现（声明）
        var outgoing: [RelationshipMetric] = []
        for dependency in extractor.extract(from: item) {
            outgoing.append(RelationshipMetric(
                source: typeName, target: dependency.targetName,
                kind: dependency.kind.rawValue
            ))
        }
        if let inherited = item.inheritedTypes {
            for parent in inherited {
                guard let parentName = parent.name else { continue }
                let resolvedParent = modulePrefixedTail(of: parentName)
                guard resolvedParent != typeName, extractor.isKnownType(resolvedParent) else { continue }
                // 继承与协议实现同属 inheritance 关系（与 RelationshipKind 一致）
                outgoing.append(RelationshipMetric(source: typeName, target: resolvedParent, kind: "inheritance"))
            }
        }

        let score = propertyCount + methodCount + inheritedCount * 2 + extensionCount * 2 + outgoing.count

        return ClassMetrics(
            typeName: typeName,
            displayName: item.displayName ?? item.name ?? typeName,
            kind: kind.shortName,
            module: moduleName(for: item),
            filePath: item.effectiveFilePath ?? "",
            accessLevel: item.accessibility?.displayName ?? "internal",
            propertyCount: propertyCount,
            methodCount: methodCount,
            privateMemberCount: privateCount,
            publicMemberCount: publicCount,
            internalMemberCount: internalCount,
            staticMemberCount: staticCount,
            inheritedTypeCount: inheritedCount,
            extensionCount: extensionCount,
            genericParameterCount: genericCount,
            outgoing: outgoing,
            incoming: [],
            complexityScore: score
        )
    }

    // MARK: - 入边关系

    private static func attachIncoming(to metrics: [ClassMetrics]) -> [ClassMetrics] {
        var incomingByName: [String: [RelationshipMetric]] = [:]
        for metric in metrics {
            for relation in metric.outgoing {
                incomingByName[relation.target, default: []].append(relation)
            }
        }
        return metrics.map { metric in
            ClassMetrics(
                typeName: metric.typeName, displayName: metric.displayName,
                kind: metric.kind, module: metric.module, filePath: metric.filePath,
                accessLevel: metric.accessLevel,
                propertyCount: metric.propertyCount, methodCount: metric.methodCount,
                privateMemberCount: metric.privateMemberCount,
                publicMemberCount: metric.publicMemberCount,
                internalMemberCount: metric.internalMemberCount,
                staticMemberCount: metric.staticMemberCount,
                inheritedTypeCount: metric.inheritedTypeCount,
                extensionCount: metric.extensionCount,
                genericParameterCount: metric.genericParameterCount,
                outgoing: metric.outgoing,
                incoming: incomingByName[metric.typeName] ?? [],
                complexityScore: metric.complexityScore
            )
        }
    }

    // MARK: - 模块维度

    private static func moduleOrder(in classes: [ClassMetrics]) -> [String] {
        var order: [String] = []
        for metric in classes where !order.contains(metric.module) {
            order.append(metric.module)
        }
        return order
    }

    private static func moduleMetrics(named name: String, in classes: [ClassMetrics]) -> ModuleMetrics? {
        let members = classes.filter { $0.module == name }
        guard !members.isEmpty else { return nil }

        var outgoing: [String: Int] = [:]
        var incoming: [String: Int] = [:]
        for metric in members {
            for relation in metric.outgoing where relation.source != relation.target {
                guard let targetModule = moduleName(of: relation.target, in: classes) else { continue }
                if targetModule != name { outgoing[targetModule, default: 0] += 1 }
            }
            for relation in metric.incoming where relation.source != relation.target {
                guard let sourceModule = moduleName(of: relation.source, in: classes) else { continue }
                if sourceModule != name { incoming[sourceModule, default: 0] += 1 }
            }
        }
        let path = members.compactMap(\.filePath).first ?? ""
        return ModuleMetrics(
            name: name,
            path: path,
            typeCount: members.count,
            outgoingCoupling: outgoing.sortedByKey(),
            incomingCoupling: incoming.sortedByKey()
        )
    }

    /// 某类型名所属的模块名（遍历所有类的 module）。
    private static func moduleName(of typeName: String, in classes: [ClassMetrics]) -> String? {
        classes.first { $0.typeName == typeName || $0.displayName == typeName }?.module
    }

    /// 构建模块耦合矩阵（values[i][j] = 模块 i 依赖模块 j 的跨模块关系数）。
    private static func couplingMatrix(modules: [ModuleMetrics], allClasses: [ClassMetrics]) -> CouplingMatrix {
        let names = modules.map(\.name)
        var values = Array(repeating: Array(repeating: 0, count: names.count), count: names.count)
        for metric in allClasses {
            guard let i = names.firstIndex(of: metric.module) else { continue }
            for relation in metric.outgoing where relation.source != relation.target {
                guard let targetModule = moduleName(of: relation.target, in: allClasses),
                      let j = names.firstIndex(of: targetModule),
                      i != j else { continue }
                values[i][j] += 1
            }
        }
        return CouplingMatrix(labels: names, values: values)
    }

    // MARK: - 工具

    private static func isMember(_ element: SyntaxStructure) -> Bool {
        element.kind == .varInstance || element.kind == .varStatic
            || element.kind == .functionMethodInstance || element.kind == .functionMethodStatic
    }

    private static func isPrivate(_ access: ElementAccessibility?) -> Bool {
        access == .private || access == .fileprivate
    }

    private static func isPublic(_ access: ElementAccessibility?) -> Bool {
        access == .open || access == .public
    }

    /// 类型所属模块名：优先 group 名（配置了 groups），否则源文件所在文件夹名。
    private static func moduleName(for item: SyntaxStructure) -> String {
        if let groupName = item.groupName, !groupName.isEmpty {
            return groupName
        }
        guard let filePath = item.effectiveFilePath else { return "Unknown" }
        let directory = (filePath as NSString).deletingLastPathComponent
        let name = (directory as NSString).lastPathComponent
        return name.isEmpty ? "Unknown" : name
    }

    /// 取模块前缀限定名的最后一段（`CrossNetworkDomain.Frame` → `Frame`）。
    private static func modulePrefixedTail(of name: String) -> String {
        guard let last = name.split(separator: ".").last else { return name }
        return String(last)
    }
}

private extension Dictionary where Key == String, Value == Int {
    /// 按键排序后输出，保证 JSON / 文本输出稳定。
    func sortedByKey() -> [String: Int] {
        Dictionary(uniqueKeysWithValues: keys.sorted().map { ($0, self[$0]!) })
    }
}

private extension ElementKind {
    /// 短名：`source.lang.swift.decl.class` → `class`
    var shortName: String {
        rawValue.components(separatedBy: ".").last ?? rawValue
    }
}

private extension ElementAccessibility {
    /// 短名：`source.lang.swift.accessibility.public` → `public`
    var displayName: String {
        switch self {
        case .open: return "open"
        case .public: return "public"
        case .package: return "package"
        case .internal: return "internal"
        case .private: return "private"
        case .fileprivate: return "fileprivate"
        case .other: return "unknown"
        }
    }
}
