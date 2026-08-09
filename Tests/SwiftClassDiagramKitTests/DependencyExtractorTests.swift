import XCTest
@testable import SwiftClassDiagramKit

/// 关系推导（组合 = 属性/初始化器依赖，关联 = 方法签名依赖）的单元测试。
final class DependencyExtractorTests: XCTestCase {
    private func extractor(items: [SyntaxStructure]) -> DependencyExtractor {
        DependencyExtractor(items: items)
    }

    // MARK: - 组合：属性声明依赖

    func test_extract_propertyType_emitsComposition() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "User", substructure: [
            SyntaxStructure(kind: .varInstance, name: "profile", typename: "Profile"),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "Profile")])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertEqual(deps.count, 1)
        XCTAssertEqual(deps.first?.kind, .composition)
        XCTAssertEqual(deps.first?.targetName, "Profile")
        XCTAssertEqual(deps.first?.sourceName, "User")
    }

    // MARK: - 组合：初始化器参数依赖

    func test_extract_initParam_emitsComposition() {
        // Given: SourceKit 将 `init` 报为 method.instance，需按构造器语义归为组合
        let item = SyntaxStructure(kind: .struct, name: "User", substructure: [
            SyntaxStructure(kind: .functionMethodInstance, name: "init(profile:)", substructure: [
                SyntaxStructure(kind: .varParameter, name: "profile", typename: "Profile"),
            ]),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "Profile")])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertEqual(deps.count, 1)
        XCTAssertEqual(deps.first?.kind, .composition)
    }

    func test_extract_constructorParam_emitsComposition() {
        // Given: 部分 SDK 解析下 init 报为 constructor
        let item = SyntaxStructure(kind: .struct, name: "Frame", substructure: [
            SyntaxStructure(kind: .functionConstructor, name: "init(user:)", substructure: [
                SyntaxStructure(kind: .varParameter, name: "user", typename: "User"),
            ]),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "User")])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertEqual(deps.count, 1)
        XCTAssertEqual(deps.first?.kind, .composition)
        XCTAssertEqual(deps.first?.targetName, "User")
    }

    // MARK: - 关联：方法签名依赖

    func test_extract_methodParameterAndReturn_emitsAssociation() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "Frame", substructure: [
            SyntaxStructure(kind: .functionMethodInstance, name: "decode(peer:)", substructure: [
                SyntaxStructure(kind: .varParameter, name: "peer", typename: "Peer"),
            ], typename: "String"),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "Peer")])

        // When
        let deps = extractor.extract(from: item)

        // Then: String 为外部类型被过滤，仅保留 Peer 关联
        XCTAssertEqual(deps.count, 1)
        XCTAssertEqual(deps.first?.kind, .association)
        XCTAssertEqual(deps.first?.targetName, "Peer")
    }

    func test_extract_staticMethodReturn_emitsAssociation() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "Factory", substructure: [
            SyntaxStructure(kind: .functionMethodStatic, name: "make()", typename: "User"),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "User")])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertEqual(deps.count, 1)
        XCTAssertEqual(deps.first?.kind, .association)
        XCTAssertEqual(deps.first?.targetName, "User")
    }

    // MARK: - 类型清洗与外部类型过滤

    func test_extract_genericAndOptionalType_resolvesKnownType() {
        // Given
        let item = SyntaxStructure(kind: .class, name: "NetworkSDK", substructure: [
            SyntaxStructure(kind: .varInstance, name: "cache", typename: "[String: Peer]?"),
            SyntaxStructure(kind: .functionMethodInstance, name: "fetch()", substructure: [], typename: "Result<User, Error>"),
        ])
        let extractor = extractor(items: [
            item,
            SyntaxStructure(kind: .struct, name: "Peer"),
            SyntaxStructure(kind: .struct, name: "User"),
        ])

        // When
        let deps = extractor.extract(from: item)

        // Then: 泛型/可选剥离后仍能解析 Peer 与 User
        let targets = Set(deps.map { $0.targetName })
        XCTAssertTrue(targets.contains("Peer"))
        XCTAssertTrue(targets.contains("User"))
        XCTAssertFalse(deps.contains { $0.targetName == "String" })
        XCTAssertFalse(deps.contains { $0.targetName == "Error" })
    }

    func test_extract_unknownExternalType_filteredOut() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "User", substructure: [
            SyntaxStructure(kind: .varInstance, name: "id", typename: "UUID"),
        ])
        let extractor = extractor(items: [item])

        // When
        let deps = extractor.extract(from: item)

        // Then: UUID 不在图中，不推导
        XCTAssertTrue(deps.isEmpty)
    }

    func test_extract_selfReference_excluded() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "Node", substructure: [
            SyntaxStructure(kind: .varInstance, name: "next", typename: "Node"),
        ])
        let extractor = extractor(items: [item])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertTrue(deps.isEmpty)
    }

    func test_extract_duplicateDependency_deduplicated() {
        // Given
        let item = SyntaxStructure(kind: .struct, name: "User", substructure: [
            SyntaxStructure(kind: .varInstance, name: "profile", typename: "Profile"),
            SyntaxStructure(kind: .varInstance, name: "primaryProfile", typename: "Profile"),
        ])
        let extractor = extractor(items: [item, SyntaxStructure(kind: .struct, name: "Profile")])

        // When
        let deps = extractor.extract(from: item)

        // Then
        XCTAssertEqual(deps.count, 1)
    }
}
