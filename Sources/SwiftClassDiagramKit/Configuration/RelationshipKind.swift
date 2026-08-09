import Foundation

/// 类图关系类型（与模板 `elements.relationships` / `groupSettings.crossGroupRelationships` 对应）。
///
/// 五类关系：
/// - `inheritance`：继承 + 协议实现（`<|--`、`<|..`）
/// - `association`：关联（方法签名依赖，`-->`）
/// - `aggregation`：聚合（属性/初始化器依赖的非拥有语义，`o--`）
/// - `composition`：组合（属性/初始化器依赖的拥有语义，`*--`）
/// - `dependency`：扩展依赖（extension 与主类型的连接，`<..`）
public enum RelationshipKind: String, Codable, CaseIterable, Sendable {
    /// 继承 + 实现（class/struct 继承与协议 conform）
    case inheritance
    /// 关联（方法签名中引用其他类型）
    case association
    /// 聚合（属性/初始化器依赖，非拥有生命周期）
    case aggregation
    /// 组合（属性/初始化器依赖，拥有生命周期）
    case composition
    /// 扩展依赖（extension）
    case dependency

    /// PlantUML 链接符号
    var linkOperator: String {
        switch self {
        case .inheritance:
            return "<|--"
        case .association:
            return "-->"
        case .aggregation:
            return "o--"
        case .composition:
            return "*--"
        case .dependency:
            return "<.."
        }
    }

    /// 上游关系名称（用于 `PlantUMLContext.uniqElementAndTypes` 的映射 key）
    var upstreamName: String {
        switch self {
        case .inheritance:
            return "inherits"
        case .association:
            return "associates"
        case .aggregation:
            return "aggregates"
        case .composition:
            return "composes"
        case .dependency:
            return "ext"
        }
    }
}
