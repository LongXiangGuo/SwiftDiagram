import Foundation

/// 分组设置（与模板 `groupSettings:` 段一一对应）。
///
/// - `groups`：需要分组的文件夹列表。不配置时 Web 控制台默认把根目录一级目录
///   全部加入为 `enable: false` 的 group（disabled 的 group 不绘制 package、
///   不应用任何覆盖规则）。
/// - `elements`：group 级 elements 覆盖（P1，仅当 `enable == true` 且存在开启的 group 时生效）。
/// - `crossGroupRelationships`：跨 group 关系开关与单行聚合选项。
public struct GroupSettings: Codable, Sendable {
    /// 分组定义列表（`enable: true` 的 group 才会真正生效）
    public var groups: [GroupSetting]
    /// group 级 elements / relationships 覆盖（P1/P2）
    public var elements: GroupElementsOptions
    /// 跨 group 关系规则
    public var crossGroupRelationships: CrossGroupRelationships

    public init(
        groups: [GroupSetting] = [],
        elements: GroupElementsOptions = GroupElementsOptions(),
        crossGroupRelationships: CrossGroupRelationships = CrossGroupRelationships()
    ) {
        self.groups = groups
        self.elements = elements
        self.crossGroupRelationships = crossGroupRelationships
    }

    /// 已开启的分组列表。
    public var enabledGroups: [GroupSetting] {
        groups.filter(\.enable)
    }
}

/// 单个分组：按文件夹将类型聚合为 UML 图上的一个 package。
public struct GroupSetting: Codable, Sendable {
    /// 分组名称（PlantUML package 标题）
    public var name: String
    /// 归属该分组的文件夹（相对路径或绝对路径，支持通配符 `*`）
    public var folder: String
    /// 是否开启该分组（默认 `false`，开启后才会绘制 package 并应用覆盖规则）
    public var enable: Bool

    public init(name: String = "", folder: String = "", enable: Bool = false) {
        self.name = name
        self.folder = folder
        self.enable = enable
    }

    /// 判断某文件路径是否属于该分组。
    func matches(filePath: String) -> Bool {
        let folderPath = folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        guard !folderPath.isEmpty else { return false }
        // 支持通配符：转换为正则进行匹配
        if folderPath.contains("*") {
            return filePath.isMatching(searchPattern: folderPath)
        }
        // 精确路径匹配：绝对路径前缀，或相对路径后缀（文件位于该文件夹下）
        if folderPath.hasPrefix("/") {
            return filePath.hasPrefix(folderPath + "/") || filePath == folderPath
        }
        return filePath.contains("/\(folderPath)/") || filePath.hasSuffix("/\(folderPath)")
    }
}

/// group 级 elements 覆盖（优先级 P1：元素；P2：relationships）。
///
/// 所有字段可选：`nil` 表示「继承全局 elements」，非 `nil` 表示「覆盖全局 elements」。
/// `exclude` 与 relationships 的 `exclude` 支持 `$(inherit)` 特殊 token
/// （含模板拼写变体 `$(inherited)` / `$(inherted)`），表示「继承全局 exclude 并追加」。
public struct GroupElementsOptions: Codable, Sendable {
    /// 是否开启该分组下自定义的 elements 配置。
    /// 仅在存在任意一个 `enable == true` 的 group 时才生效，否则整体不生效。
    public var enable: Bool
    /// 元素排除名单（`$(inherit)` 表示继承全局 exclude 并追加）
    public var exclude: [String]?
    /// 控制类的访问级别（未设置则继承全局）
    public var havingAccessLevel: AccessLevelFilter?
    /// 控制类的方法和属性的输出过滤（未设置则继承全局）
    public var showMembersWithAccessLevel: AccessLevelFilter?
    /// 是否展示嵌套类型（未设置则继承全局）
    public var showNestedTypes: Bool?
    /// 是否展示扩展（未设置则继承全局）
    public var showExtensions: Bool?
    /// 是否展示范型（未设置则继承全局）
    public var showGenerics: Bool?
    /// 关系配置覆盖（最高优先级 P2）
    public var relationships: RelationshipOptions?

    public init(
        enable: Bool = false,
        exclude: [String]? = nil,
        havingAccessLevel: AccessLevelFilter? = nil,
        showMembersWithAccessLevel: AccessLevelFilter? = nil,
        showNestedTypes: Bool? = nil,
        showExtensions: Bool? = nil,
        showGenerics: Bool? = nil,
        relationships: RelationshipOptions? = nil
    ) {
        self.enable = enable
        self.exclude = exclude
        self.havingAccessLevel = havingAccessLevel
        self.showMembersWithAccessLevel = showMembersWithAccessLevel
        self.showNestedTypes = showNestedTypes
        self.showExtensions = showExtensions
        self.showGenerics = showGenerics
        self.relationships = relationships
    }

    /// 字段级合并：将 `self` 的非 `nil` 字段覆盖到全局 `base` 上，返回最终 `ElementOptions`。
    func applied(to base: ElementOptions) -> ElementOptions {
        ElementOptions(
            exclude: Self.resolvedExclude(groupExclude: exclude, globalExclude: base.exclude),
            havingAccessLevel: havingAccessLevel ?? base.havingAccessLevel,
            showMembersWithAccessLevel: showMembersWithAccessLevel ?? base.showMembersWithAccessLevel,
            showNestedTypes: showNestedTypes ?? base.showNestedTypes,
            showExtensions: showExtensions ?? base.showExtensions,
            showGenerics: showGenerics ?? base.showGenerics,
            relationships: relationships?.applied(to: base.relationships) ?? base.relationships
        )
    }

    /// group 级 exclude 合并：含 `$(inherit)` token 时「继承全局 + 追加」，
    /// 否则整体替换全局 exclude。
    static func resolvedExclude(groupExclude: [String]?, globalExclude: [String]) -> [String] {
        guard let groupExclude else { return globalExclude }
        let hasInheritToken = containsInheritToken(groupExclude)
        let ownTokens = groupExclude.filter { !inheritTokens.contains($0) }
        return hasInheritToken ? globalExclude + ownTokens : groupExclude
    }

    /// 继承 token 的全部合法拼写（含模板拼写变体 `$(inherted)`）。
    static let inheritTokens: Set<String> = ["$(inherit)", "$(inherited)", "$(inherted)"]

    /// 判断 exclude 列表中是否含继承 token。
    static func containsInheritToken(_ items: [String]) -> Bool {
        items.contains { inheritTokens.contains($0) }
    }
}

/// 跨 group 关系规则：控制「不同 group 之间」哪些关系类型允许绘制。
///
/// - 某类关系为 `true`：允许跨 group 绘制该类关系。
/// - `false`：该类跨 group 关系不绘制；若 `singleLine` 开启则聚合并为 group 间单行链接。
public struct CrossGroupRelationships: Codable, Sendable {
    /// 跨 group 是否允许继承关系
    public var inheritance: Bool
    /// 跨 group 是否允许关联关系
    public var association: Bool
    /// 跨 group 是否允许聚合关系
    public var aggregation: Bool
    /// 跨 group 是否允许组合关系
    public var composition: Bool
    /// 跨 group 是否允许依赖关系
    public var dependency: Bool
    /// 单行聚合选项
    public var singleLine: SingleLineOptions

    public init(
        inheritance: Bool = false,
        association: Bool = false,
        aggregation: Bool = false,
        composition: Bool = false,
        dependency: Bool = false,
        singleLine: SingleLineOptions = SingleLineOptions()
    ) {
        self.inheritance = inheritance
        self.association = association
        self.aggregation = aggregation
        self.composition = composition
        self.dependency = dependency
        self.singleLine = singleLine
    }

    /// 某类关系是否允许跨 group 绘制。
    func allows(_ kind: RelationshipKind) -> Bool {
        switch kind {
        case .inheritance:
            return inheritance
        case .association:
            return association
        case .aggregation:
            return aggregation
        case .composition:
            return composition
        case .dependency:
            return dependency
        }
    }
}

/// 单行聚合选项：把跨 group 关系合并为 group 之间的单行链接，防止线条爆量。
public struct SingleLineOptions: Codable, Sendable {
    /// 是否使用单行显示关系（默认 `true`）。跨 group 的关系被聚合为单行，
    /// 同一个 group 内的元素不受影响；若为 `false` 则不显示单行。
    public var excludeSameGroup: Bool
    /// 是否把所有 group 下的关系都合并成单行链接（默认 `true`）。
    /// 开启后任意跨 group 关系对都只输出一条 `"GroupA" -- "GroupB"`。
    public var allGroups: Bool

    public init(excludeSameGroup: Bool = true, allGroups: Bool = true) {
        self.excludeSameGroup = excludeSameGroup
        self.allGroups = allGroups
    }
}
