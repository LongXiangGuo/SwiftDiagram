import Foundation

/// 单个关系类型的开关与排除名单。
///
/// - `toggle`：是否绘制该类关系（`nil` = 继承上级规则）
/// - `exclude`：排除的目标类型名单（通配符支持 `*`）；
///   group 级配置可用 `$(inherit)` 特殊 token 表示「继承全局 exclude 并追加」
public struct RelationshipRule: Codable, Sendable {
    /// 是否绘制该类关系（`nil` = 继承上级规则）
    public var toggle: Bool?
    /// 排除的目标类型名（通配符支持 `*`）
    public var exclude: [String]?

    public init(toggle: Bool? = nil, exclude: [String]? = nil) {
        self.toggle = toggle
        self.exclude = exclude
    }

    /// group 级 exclude 中表示「继承全局 exclude 并追加」的特殊 token
    public static let inheritToken = "$(inherit)"
}

/// 五类关系（继承/关联/聚合/组合/依赖）的配置集合。
///
/// 全局默认仅开启 `inheritance`，其余四类默认关闭。
/// 应用于类型时需经 `ResolvedRule.resolve` 完成全局与 group 级合并。
public struct RelationshipOptions: Codable, Sendable {
    /// 继承关系（含协议实现）
    public var inheritance: RelationshipRule?
    /// 关联关系（方法签名依赖）
    public var association: RelationshipRule?
    /// 聚合关系（属性/初始化器依赖，非拥有语义）
    public var aggregation: RelationshipRule?
    /// 组合关系（属性/初始化器依赖，拥有语义）
    public var composition: RelationshipRule?
    /// 扩展依赖关系（extension）
    public var dependency: RelationshipRule?

    public init(
        inheritance: RelationshipRule? = RelationshipRule(toggle: true),
        association: RelationshipRule? = nil,
        aggregation: RelationshipRule? = nil,
        composition: RelationshipRule? = nil,
        dependency: RelationshipRule? = nil
    ) {
        self.inheritance = inheritance
        self.association = association
        self.aggregation = aggregation
        self.composition = composition
        self.dependency = dependency
    }

    /// 返回某类关系的配置规则。
    public func rule(for kind: RelationshipKind) -> RelationshipRule? {
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

    /// 某类关系是否启用（未配置 = 关闭）。
    public func isEnabled(_ kind: RelationshipKind) -> Bool {
        rule(for: kind)?.toggle ?? false
    }

    /// 某类关系的排除名单（未配置 = `nil`）。
    public func exclude(for kind: RelationshipKind) -> [String]? {
        rule(for: kind)?.exclude
    }
}

extension RelationshipOptions {
    /// 字段级合并：将 `self` 的非 `nil` 关系规则覆盖到 `base` 上（group 级 P2 覆盖全局 P0）。
    ///
    /// 某类关系未在 `self` 中配置时继承 `base`；配置时 `toggle` 字段覆盖，
    /// `exclude` 按「含 `$(inherit)` token → 继承全局并追加，否则整体替换」合并。
    func applied(to base: RelationshipOptions) -> RelationshipOptions {
        func mergedRule(_ kind: RelationshipKind) -> RelationshipRule? {
            guard let override = rule(for: kind) else { return base.rule(for: kind) }
            let globalRule = base.rule(for: kind)
            return RelationshipRule(
                toggle: override.toggle ?? globalRule?.toggle,
                exclude: resolvedExclude(groupExclude: override.exclude, globalExclude: globalRule?.exclude)
            )
        }
        return RelationshipOptions(
            inheritance: mergedRule(.inheritance),
            association: mergedRule(.association),
            aggregation: mergedRule(.aggregation),
            composition: mergedRule(.composition),
            dependency: mergedRule(.dependency)
        )
    }

    /// 关系 exclude 合并：含 `$(inherit)` token 时「继承全局 + 追加」，否则整体替换。
    private func resolvedExclude(groupExclude: [String]?, globalExclude: [String]?) -> [String]? {
        guard let groupExclude else { return globalExclude }
        let hasInheritToken = GroupElementsOptions.containsInheritToken(groupExclude)
        let ownTokens = groupExclude.filter { !GroupElementsOptions.inheritTokens.contains($0) }
        if hasInheritToken {
            return (globalExclude ?? []) + ownTokens
        }
        return groupExclude
    }
}
