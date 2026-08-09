import XCTest
@testable import SwiftClassDiagramKit

/// 分层配置（elements P0 / groupSettings P1·P2 / 跨组关系）的单元测试。
final class ConfigurationRulesTests: XCTestCase {
    // MARK: - AccessLevelFilter

    func test_accessLevelFilter_allowed_mapsDefaults() {
        // Given: 默认过滤（open/public/internal 开启，fileprivate/private 关闭）
        let filter = AccessLevelFilter()

        // When / Then
        XCTAssertEqual(Set(filter.allowed), Set([.open, .public, .internal, .package]))
    }

    func test_accessLevelFilter_allowed_customFlags() {
        // Given
        let filter = AccessLevelFilter(open: true, public: false, internal: false, fileprivate: true, private: true)

        // When / Then
        XCTAssertEqual(Set(filter.allowed), Set([.open, .fileprivate, .private]))
    }

    // MARK: - GroupSetting.matches

    func test_groupSetting_absolutePathPrefix_matches() {
        // Given
        let group = GroupSetting(name: "Core", folder: "/proj/Core")

        // When / Then
        XCTAssertTrue(group.matches(filePath: "/proj/Core/Frame/FrameCodec.swift"))
        XCTAssertTrue(group.matches(filePath: "/proj/Core/Frame.swift"))
        XCTAssertFalse(group.matches(filePath: "/proj/Domain/Entities/Frame.swift"))
    }

    func test_groupSetting_relativePathSegment_matches() {
        // Given
        let group = GroupSetting(name: "Domain", folder: "Domain/Entities")

        // When / Then
        XCTAssertTrue(group.matches(filePath: "/proj/Sources/Domain/Entities/User.swift"))
        XCTAssertFalse(group.matches(filePath: "/proj/Sources/Domain/Protocols/Connection.swift"))
    }

    func test_groupSetting_wildcard_matches() {
        // Given
        let group = GroupSetting(name: "Tests", folder: "**/Tests/**")

        // When / Then
        XCTAssertTrue(group.matches(filePath: "/proj/Tests/CoreTests/CodecTests.swift"))
        XCTAssertFalse(group.matches(filePath: "/proj/Sources/Core/Codec.swift"))
    }

    // MARK: - GroupElementsOptions.applied(to:)（P1 元素覆盖）

    func test_groupElements_applied_onlyNonNilFieldsOverride() {
        // Given
        var base = ElementOptions()
        base.showNestedTypes = true
        base.exclude = ["Old"]

        let overrides = GroupElementsOptions(exclude: ["$(inherted)", "New"], showNestedTypes: false)

        // When
        let merged = overrides.applied(to: base)

        // Then: exclude 含继承 token → 全局 + 追加；showNestedTypes 被覆盖
        XCTAssertEqual(merged.exclude, ["Old", "New"])
        XCTAssertFalse(merged.showNestedTypes)
        XCTAssertTrue(merged.showGenerics == base.showGenerics)
    }

    func test_groupElements_applied_excludeWithoutTokenReplaces() {
        // Given
        var base = ElementOptions()
        base.exclude = ["Old"]

        // When: group exclude 不含 $(inherit) token → 整体替换全局
        let merged = GroupElementsOptions(exclude: ["OnlyGroup"]).applied(to: base)

        // Then
        XCTAssertEqual(merged.exclude, ["OnlyGroup"])
    }

    // MARK: - RelationshipOptions.applied(to:)（P2 关系覆盖）

    func test_relationshipOptions_applied_inheritTokenMergesExcludes() {
        // Given
        var global = RelationshipOptions()
        global.inheritance = RelationshipRule(toggle: true, exclude: ["NSObject"])
        global.association = RelationshipRule(toggle: false, exclude: ["Codable"])

        let group = RelationshipOptions(
            inheritance: RelationshipRule(toggle: true, exclude: ["$(inherit)", "LocalizedError"]),
            association: RelationshipRule(toggle: true)
        )

        // When
        let merged = group.applied(to: global)

        // Then: inheritance exclude 继承全局并追加；association 开启并继承全局 exclude
        XCTAssertEqual(merged.inheritance?.exclude, ["NSObject", "LocalizedError"])
        XCTAssertTrue(merged.association?.toggle == true)
        XCTAssertEqual(merged.association?.exclude, ["Codable"])
    }

    func test_relationshipOptions_applied_inheritsUnconfiguredKinds() {
        // Given
        var global = RelationshipOptions()
        global.dependency = RelationshipRule(toggle: true, exclude: ["Sendable"])

        // When: group 未配置 dependency → 继承全局
        let merged = RelationshipOptions(inheritance: RelationshipRule(toggle: false)).applied(to: global)

        // Then
        XCTAssertTrue(merged.dependency?.toggle == true)
        XCTAssertEqual(merged.dependency?.exclude, ["Sendable"])
        XCTAssertFalse(merged.inheritance?.toggle ?? true)
    }

    // MARK: - ResolvedRule.resolve（P0 → P1/P2 三级合并）

    func test_resolve_noGroup_appliesGlobalOnly() {
        // Given
        var config = Configuration()
        config.elements.exclude = ["NW*"]

        // When
        let rule = ResolvedRule.resolve(typeName: "NetworkSDK", filePath: "/proj/Core/NetworkSDK.swift", configuration: config)

        // Then
        XCTAssertNil(rule.groupName)
        XCTAssertEqual(rule.elements.exclude, ["NW*"])
    }

    func test_resolve_disabledGroup_ignored() {
        // Given: group 存在但 enable = false
        var config = Configuration()
        config.groupSettings.groups = [GroupSetting(name: "Core", folder: "Core", enable: false)]

        // When
        let rule = ResolvedRule.resolve(typeName: "Frame", filePath: "/proj/Core/Frame/Frame.swift", configuration: config)

        // Then: 不归属任何 group，也不应用覆盖
        XCTAssertNil(rule.groupName)
    }

    func test_resolve_enabledGroup_assignedGroupName() {
        // Given
        var config = Configuration()
        config.groupSettings.groups = [
            GroupSetting(name: "Core", folder: "Core", enable: true),
            GroupSetting(name: "All", folder: "Core", enable: true),
        ]

        // When: 命中第一个开启的 group
        let rule = ResolvedRule.resolve(typeName: "Frame", filePath: "/proj/Core/Frame/Frame.swift", configuration: config)

        // Then
        XCTAssertEqual(rule.groupName, "Core")
    }

    func test_resolve_enabledGroup_appliesP1Overrides() {
        // Given
        var config = Configuration()
        config.elements.exclude = ["Global"]
        config.groupSettings.groups = [GroupSetting(name: "Core", folder: "Core", enable: true)]
        config.groupSettings.elements = GroupElementsOptions(
            enable: true,
            exclude: ["$(inherited)", "CoreOnly"],
            showNestedTypes: true
        )

        // When
        let rule = ResolvedRule.resolve(typeName: "Frame", filePath: "/proj/Core/Frame/Frame.swift", configuration: config)

        // Then: P1 覆盖全局（exclude 继承 + 追加）
        XCTAssertEqual(rule.groupName, "Core")
        XCTAssertEqual(rule.elements.exclude, ["Global", "CoreOnly"])
        XCTAssertTrue(rule.elements.showNestedTypes)
    }

    func test_resolve_enabledGroup_elementsMasterOff_keepsGlobal() {
        // Given: group 开启但 elements.enable = false → 不应用覆盖
        var config = Configuration()
        config.elements.showNestedTypes = false
        config.groupSettings.groups = [GroupSetting(name: "Core", folder: "Core", enable: true)]
        config.groupSettings.elements = GroupElementsOptions(enable: false, showNestedTypes: true)

        // When
        let rule = ResolvedRule.resolve(typeName: "Frame", filePath: "/proj/Core/Frame/Frame.swift", configuration: config)

        // Then: 仍归属 group，但元素规则回退全局
        XCTAssertEqual(rule.groupName, "Core")
        XCTAssertFalse(rule.elements.showNestedTypes)
    }

    func test_resolve_enabledGroup_appliesP2Relationships() {
        // Given: 全局关系全关，group 开启 association
        var config = Configuration()
        config.groupSettings.groups = [GroupSetting(name: "Core", folder: "Core", enable: true)]
        config.groupSettings.elements = GroupElementsOptions(
            enable: true,
            relationships: RelationshipOptions(association: RelationshipRule(toggle: true))
        )

        // When
        let rule = ResolvedRule.resolve(typeName: "Frame", filePath: "/proj/Core/Frame/Frame.swift", configuration: config)

        // Then: P2 覆盖后的关系配置生效
        XCTAssertTrue(rule.relationships.isEnabled(.association))
    }

    // MARK: - CrossGroupRelationships

    func test_crossGroupRelationships_allows_perKind() {
        // Given
        let relations = CrossGroupRelationships(inheritance: true, association: true)

        // When / Then
        XCTAssertTrue(relations.allows(.inheritance))
        XCTAssertTrue(relations.allows(.association))
        XCTAssertFalse(relations.allows(.aggregation))
        XCTAssertFalse(relations.allows(.composition))
        XCTAssertFalse(relations.allows(.dependency))
    }

    // MARK: - RelationshipKind

    func test_relationshipKind_linkOperators() {
        // When / Then
        XCTAssertEqual(RelationshipKind.inheritance.linkOperator, "<|--")
        XCTAssertEqual(RelationshipKind.dependency.linkOperator, "<..")
        XCTAssertEqual(RelationshipKind.association.linkOperator, "-->")
        XCTAssertEqual(RelationshipKind.aggregation.linkOperator, "o--")
        XCTAssertEqual(RelationshipKind.composition.linkOperator, "*--")
    }
}
