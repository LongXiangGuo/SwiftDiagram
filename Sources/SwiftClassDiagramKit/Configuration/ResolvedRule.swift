import Foundation

/// 规则合并后的最终结果：作用于单个类型（class/struct/enum/protocol/extension）。
///
/// 合并优先级（三级）：
/// - P0：全局 `configuration.elements`（最低）
/// - P1：`groupSettings.elements`（元素级覆盖，仅当命中「已开启的 group」且 `elements.enable == true`）
/// - P2：`groupSettings.elements.relationships`（关系级覆盖，优先级最高）
///
/// 未命中任何 group 的类型仅应用全局 P0。
public struct ResolvedRule {
    /// 合并后的元素规则（含访问级别、排除名单、关系配置）
    public let elements: ElementOptions
    /// 类型所属分组名（仅「已开启」的 group 会归属；未分组为 `nil`）
    public let groupName: String?

    /// 合并后的关系配置（P2 覆盖后的结果，供关系生成直接使用）。
    public var relationships: RelationshipOptions {
        elements.relationships
    }

    /// 解析单个类型生效的完整规则。
    /// - Parameters:
    ///   - typeName: 类型的全名（`fullName`，可能含命名空间前缀）
    ///   - filePath: 类型所在文件路径
    ///   - configuration: 全局配置
    public static func resolve(typeName: String, filePath: String?, configuration: Configuration) -> ResolvedRule {
        // P0：全局 elements
        var mergedElements = configuration.elements

        // 分组归属：命中第一个「已开启」且文件夹匹配的 group
        let matchingGroup = configuration.groupSettings.enabledGroups.first { group in
            filePath.map { group.matches(filePath: $0) } ?? false
        }

        // P1 / P2：group 级覆盖（仅当开启分组且 elements.enable == true）
        if matchingGroup != nil, configuration.groupSettings.elements.enable {
            mergedElements = configuration.groupSettings.elements.applied(to: mergedElements)
        }

        return ResolvedRule(elements: mergedElements, groupName: matchingGroup?.name)
    }
}
