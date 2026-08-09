import XCTest
@testable import SwiftClassDiagramKit

/// 度量报告（复杂度统计 + 模块耦合矩阵）单元测试。
final class MetricsReportTests: XCTestCase {
    // MARK: - Helpers

    /// 构造带 filePath / group 的类型结构。
    private func item(
        _ kind: ElementKind, _ name: String,
        path: String = "/tmp/Mod/File.swift", group: String? = nil,
        inheritedTypes: [SyntaxStructure]? = nil,
        substructure: [SyntaxStructure] = []
    ) -> SyntaxStructure {
        let structure = SyntaxStructure(
            inheritedTypes: inheritedTypes,
            kind: kind, name: name, substructure: substructure
        )
        structure.filePath = path
        if let group {
            structure.resolvedRule = ResolvedRule(elements: ElementOptions(), groupName: group)
        }
        return structure
    }

    // MARK: - 类复杂度统计

    func test_collect_classComplexity_countsMembers() {
        // Given: 一个 class，含 2 公开属性、1 私有属性、2 静态方法、1 私有方法
        let clazz = item(.class, "Service", path: "/tmp/App/Service.swift", group: "App", substructure: [
            SyntaxStructure(accessibility: .public, kind: .varInstance, name: "publicProp", typename: "String"),
            SyntaxStructure(accessibility: .public, kind: .varInstance, name: "otherProp", typename: "Int"),
            SyntaxStructure(accessibility: .private, kind: .varInstance, name: "secret", typename: "Data"),
            SyntaxStructure(accessibility: .public, kind: .functionMethodStatic, name: "make()", typename: "Service"),
            SyntaxStructure(kind: .functionMethodStatic, name: "reset()", typename: "Void"),
            SyntaxStructure(accessibility: .private, kind: .functionMethodInstance, name: "hack()", typename: "Void"),
        ])

        // When
        let report = MetricsCollector.collect(items: [clazz], fileCount: 1)

        // Then
        let metric = report.classes.first!
        XCTAssertEqual(metric.propertyCount, 3)
        XCTAssertEqual(metric.methodCount, 3)
        XCTAssertEqual(metric.privateMemberCount, 2)
        XCTAssertEqual(metric.publicMemberCount, 3)
        XCTAssertEqual(metric.internalMemberCount, 1)
        XCTAssertEqual(metric.staticMemberCount, 2)
        XCTAssertEqual(metric.module, "App")
        XCTAssertEqual(report.totalTypeCount, 1)
    }

    // MARK: - 模块分组

    func test_collect_moduleGrouping_prefersGroupName() {
        // Given: 同文件夹下两个类，分属不同 group
        let a = item(.struct, "A", path: "/tmp/Mod/A.swift", group: "Alpha")
        let b = item(.struct, "B", path: "/tmp/Mod/B.swift", group: "Beta")

        // When
        let report = MetricsCollector.collect(items: [a, b], fileCount: 2)

        // Then
        XCTAssertEqual(report.modules.map(\.name).sorted(), ["Alpha", "Beta"])
        XCTAssertEqual(report.modules.first { $0.name == "Alpha" }?.typeCount, 1)
    }

    func test_collect_moduleGrouping_fallsBackToFolder() {
        // Given: 未配置 group，按文件夹名分模块
        let a = item(.struct, "A", path: "/tmp/Domain/A.swift")
        let b = item(.struct, "B", path: "/tmp/Core/B.swift")

        // When
        let report = MetricsCollector.collect(items: [a, b], fileCount: 2)

        // Then
        XCTAssertEqual(report.modules.map(\.name).sorted(), ["Core", "Domain"])
    }

    // MARK: - 模块耦合矩阵

    func test_collect_couplingMatrix_crossModuleCounts() {
        // Given: Domain 的 User 被 Core 的 UserStore（属性 + 方法参数）依赖
        let user = item(.struct, "User", path: "/tmp/Domain/User.swift", group: "Domain", substructure: [
            SyntaxStructure(accessibility: .public, kind: .varInstance, name: "id", typename: "Int"),
        ])
        let store = item(.class, "UserStore", path: "/tmp/Core/UserStore.swift", group: "Core", substructure: [
            SyntaxStructure(accessibility: .private, kind: .varInstance, name: "cache", typename: "[User]"),
            SyntaxStructure(accessibility: .public, kind: .functionMethodInstance, name: "fetch()", substructure: [], typename: "User"),
        ])

        // When
        let report = MetricsCollector.collect(items: [user, store], fileCount: 2)

        // Then: Core → Domain 两条（组合 + 关联），Domain → Core 0 条
        let labels = report.couplingMatrix.labels
        let coreIndex = labels.firstIndex(of: "Core")!
        let domainIndex = labels.firstIndex(of: "Domain")!
        XCTAssertEqual(report.couplingMatrix.values[coreIndex][domainIndex], 2)
        XCTAssertEqual(report.couplingMatrix.values[domainIndex][coreIndex], 0)
        let coreModule = report.modules.first { $0.name == "Core" }!
        XCTAssertEqual(coreModule.outgoingCoupling["Domain"], 2)
        XCTAssertEqual(coreModule.incomingCoupling.count, 0)
    }

    // MARK: - 入边关系

    func test_collect_incomingRelationships_filledByReversal() {
        // Given: A 依赖 B（组合），B 无出边
        let b = item(.struct, "B", path: "/tmp/Domain/B.swift", group: "Domain")
        let a = item(.class, "A", path: "/tmp/Core/A.swift", group: "Core", substructure: [
            SyntaxStructure(accessibility: .private, kind: .varInstance, name: "b", typename: "B"),
        ])

        // When
        let report = MetricsCollector.collect(items: [a, b], fileCount: 2)

        // Then
        let bMetric = report.classes.first { $0.displayName == "B" }!
        XCTAssertEqual(bMetric.incoming.count, 1)
        XCTAssertEqual(bMetric.incoming.first?.source, "A")
        XCTAssertEqual(bMetric.incoming.first?.kind, "composition")
    }

    // MARK: - 继承/实现关系

    func test_collect_inheritanceAndProtocol_filledAsRelationships() {
        // Given: UserService 继承 BaseService 并实现 ServiceProtocol
        let base = item(.class, "BaseService", path: "/tmp/Domain/BaseService.swift", group: "Domain")
        let protocolItem = item(.protocol, "ServiceProtocol", path: "/tmp/Domain/ServiceProtocol.swift", group: "Domain")
        let service = item(
            .class, "UserService", path: "/tmp/SDK/UserService.swift", group: "SDK",
            inheritedTypes: [
                SyntaxStructure(kind: .class, name: "BaseService"),
                SyntaxStructure(kind: .protocol, name: "ServiceProtocol"),
            ]
        )

        // When
        let report = MetricsCollector.collect(items: [base, protocolItem, service], fileCount: 3)

        // Then
        let serviceMetric = report.classes.first { $0.displayName == "UserService" }!
        XCTAssertEqual(serviceMetric.inheritedTypeCount, 2)
        XCTAssertEqual(serviceMetric.outgoing.count, 2)
        XCTAssertTrue(serviceMetric.outgoing.contains { $0.kind == "inheritance" && $0.target == "BaseService" })
        XCTAssertTrue(serviceMetric.outgoing.contains { $0.kind == "inheritance" && $0.target == "ServiceProtocol" })
    }

    // MARK: - 扩展数

    func test_collect_extensionCount_countsSameNameExtensions() {
        // Given: Frame 本体 + 两个 Frame 扩展
        let frame = item(.struct, "Frame", path: "/tmp/Domain/Frame.swift", group: "Domain", substructure: [
            SyntaxStructure(accessibility: .public, kind: .varInstance, name: "id", typename: "Int"),
        ])
        let ext1 = item(.extension, "Frame", path: "/tmp/Domain/Frame+Encodable.swift", group: "Domain", substructure: [
            SyntaxStructure(accessibility: .public, kind: .functionMethodInstance, name: "encode()", typename: "Void"),
        ])
        let ext2 = item(.extension, "Frame", path: "/tmp/Domain/Frame+Display.swift", group: "Domain")

        // When
        let report = MetricsCollector.collect(items: [frame, ext1, ext2], fileCount: 3)

        // Then
        let frameMetric = report.classes.first { $0.displayName == "Frame" && $0.kind == "struct" }!
        XCTAssertEqual(frameMetric.extensionCount, 2)
    }

    // MARK: - Markdown 渲染

    func test_markdown_render_containsMatrixAndRanking() {
        // Given
        let user = item(.struct, "User", path: "/tmp/Domain/User.swift", group: "Domain")
        let store = item(.class, "UserStore", path: "/tmp/Core/UserStore.swift", group: "Core", substructure: [
            SyntaxStructure(accessibility: .private, kind: .varInstance, name: "cache", typename: "[User]"),
        ])
        let report = MetricsCollector.collect(items: [user, store], fileCount: 2)

        // When
        let markdown = report.markdown(topRankCount: 5)

        // Then
        XCTAssertTrue(markdown.contains("模块耦合矩阵"))
        XCTAssertTrue(markdown.contains("设计复杂度排名"))
        XCTAssertTrue(markdown.contains("| Core |"))
        XCTAssertTrue(markdown.contains("UserStore"))
    }
}
