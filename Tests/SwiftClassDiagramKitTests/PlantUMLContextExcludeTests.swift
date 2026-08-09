import XCTest
@testable import SwiftClassDiagramKit

/// 验证 `elements.exclude` 会同时裁剪「指向被排除类型」的链接线。
///
/// 语义：`elements.exclude` 过滤该类型及其全部信息（属性、方法、关系），
/// 因此 `"@unchecked Sendable" <|-- Foo` 这类幽灵节点链接应一并被移除，
/// 而不是仅依赖 `relationships.<kind>.exclude`。
final class PlantUMLContextExcludeTests: XCTestCase {
    private func makeContext(elementExclude: [String], inheritanceExclude: [String]? = nil) -> PlantUMLContext {
        var configuration = Configuration.default
        configuration.elements.exclude = elementExclude
        if let inheritanceExclude {
            configuration.elements.relationships.inheritance = RelationshipRule(toggle: true, exclude: inheritanceExclude)
        }
        return PlantUMLContext(configuration: configuration)
    }

    private func makeClass(named name: String) -> SyntaxStructure {
        SyntaxStructure(kind: .class, name: name)
    }

    // MARK: - 元素级 exclude 裁剪链接

    func test_addLinking_elementExcludedParent_linkSkipped() {
        // Given: 全局 elements.exclude 含 @unchecked Sendable；关系级 exclude 未配置
        let context = makeContext(elementExclude: ["@unchecked Sendable"])
        let item = makeClass(named: "Foo")

        // When: Foo 实现 @unchecked Sendable，生成 `"@unchecked Sendable" <|-- Foo`
        context.addLinking(item: item, parent: SyntaxStructure(name: "@unchecked Sendable"))

        // Then: 链接被裁剪
        XCTAssertTrue(context.connections.isEmpty)
    }

    func test_addLinking_elementExcludedParentWildcard_linkSkipped() {
        // Given: 通配符 `Sendable` 命中
        let context = makeContext(elementExclude: ["Sendable"])
        let item = makeClass(named: "Foo")

        // When
        context.addLinking(item: item, parent: SyntaxStructure(name: "Sendable"))

        // Then
        XCTAssertTrue(context.connections.isEmpty)
    }

    func test_addLinking_derivedLink_toExcludedTarget_skipped() {
        // Given: 开启关联关系，元素级 exclude 含 String
        var configuration = Configuration.default
        configuration.elements.exclude = ["String"]
        configuration.elements.relationships.association = RelationshipRule(toggle: true)
        let context = PlantUMLContext(configuration: configuration)
        let item = makeClass(named: "Foo")

        // When: 推导的关联线 Foo --> String（关系级 exclude 未命中，元素级命中）
        context.addDerivedLinking(from: "Foo", to: "String", kind: .association, item: item)

        // Then
        XCTAssertTrue(context.connections.isEmpty)
    }

    // MARK: - 非排除类型不受影响

    func test_addLinking_nonExcludedParent_linkKept() {
        // Given
        let context = makeContext(elementExclude: ["@unchecked Sendable"])
        let item = makeClass(named: "Foo")

        // When: Foo 继承项目内类型 Bar
        context.addLinking(item: item, parent: SyntaxStructure(name: "Bar"))

        // Then: 链接保留
        XCTAssertEqual(context.connections.count, 1)
        XCTAssertTrue(context.connections[0].contains("Bar"))
    }

    func test_addLinking_elementExcludeWithoutInherit_keepsProjectLinks() {
        // Given: 排除 @unchecked Sendable，不排除项目类型 Foo、Bar
        let context = makeContext(elementExclude: ["@unchecked Sendable", "Sendable"])
        let foo = makeClass(named: "Foo")

        // When
        context.addLinking(item: foo, parent: SyntaxStructure(name: "Bar"))

        // Then
        XCTAssertEqual(context.connections.count, 1)
    }

    // MARK: - 关系级 exclude 仍然生效

    func test_addLinking_relationshipExclude_stillApplies() {
        // Given: 关系级 inheritance.exclude 含 NSObject
        let context = makeContext(elementExclude: [], inheritanceExclude: ["NSObject"])
        let item = makeClass(named: "Foo")

        // When
        context.addLinking(item: item, parent: SyntaxStructure(name: "NSObject"))

        // Then
        XCTAssertTrue(context.connections.isEmpty)
    }

    func test_addLinking_relationshipExcludePlusElementExclude_merged() {
        // Given: 元素级 + 关系级排除同时生效
        let context = makeContext(elementExclude: ["@unchecked Sendable"], inheritanceExclude: ["NSObject"])
        let foo = makeClass(named: "Foo")

        // When
        context.addLinking(item: foo, parent: SyntaxStructure(name: "NSObject"))
        context.addLinking(item: foo, parent: SyntaxStructure(name: "@unchecked Sendable"))

        // Then: 两条都被裁剪
        XCTAssertTrue(context.connections.isEmpty)
    }
}
