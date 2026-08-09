import Foundation

/// 全局 elements 设置（最低优先级 P0）。
///
/// 与模板 `elements:` 段一一对应；`relationships` 嵌套于其中。
public struct ElementOptions: Codable, Sendable {
    /// 过滤这些 elements 所有的相关信息（类图、属性、关系等），通配符支持 `*`
    public var exclude: [String]
    /// 控制类的访问级别（根据可见性过滤类本身）
    public var havingAccessLevel: AccessLevelFilter
    /// 控制类的方法和属性的输出过滤
    public var showMembersWithAccessLevel: AccessLevelFilter
    /// 是否展示嵌套类型
    public var showNestedTypes: Bool
    /// 是否展示该类的扩展（默认 `false`）
    public var showExtensions: Bool
    /// 是否展示该类引用的范型
    public var showGenerics: Bool
    /// 关系配置（继承/关联/聚合/组合/依赖）
    public var relationships: RelationshipOptions

    public init(
        exclude: [String] = [],
        havingAccessLevel: AccessLevelFilter = AccessLevelFilter(),
        showMembersWithAccessLevel: AccessLevelFilter = AccessLevelFilter(),
        showNestedTypes: Bool = false,
        showExtensions: Bool = false,
        showGenerics: Bool = false,
        relationships: RelationshipOptions = RelationshipOptions()
    ) {
        self.exclude = exclude
        self.havingAccessLevel = havingAccessLevel
        self.showMembersWithAccessLevel = showMembersWithAccessLevel
        self.showNestedTypes = showNestedTypes
        self.showExtensions = showExtensions
        self.showGenerics = showGenerics
        self.relationships = relationships
    }
}
