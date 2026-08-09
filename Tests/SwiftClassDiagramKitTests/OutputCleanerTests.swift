import XCTest
@testable import SwiftClassDiagramKit

final class OutputCleanerTests: XCTestCase {
    // MARK: - 幽灵类型残余行（②）

    func test_clean_anyObjectRealizeLink_removed() {
        // Given
        let input = "AnyObject <|.. ConnectionProtocol"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertFalse(output.contains("AnyObject"))
    }

    func test_clean_uncheckedSendableLink_removed() {
        // Given
        let input = "\"@unchecked Sendable\" -- Foo"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertFalse(output.contains("@unchecked Sendable"))
    }

    // MARK: - 枚举原始值关联线（①）

    func test_clean_enumRawValueLink_removed() {
        // Given
        let input = "String -- MessageKind"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertFalse(output.contains("String --"))
    }

    func test_clean_caseIterableRealizeLink_removed() {
        // Given
        let input = "CaseIterable <|.. MessageKind"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertFalse(output.contains("CaseIterable"))
    }

    // MARK: - 有效行必须保留

    func test_clean_legitAssociationLink_kept() {
        // Given
        let input = "PeerSession <|.. ConnectionProtocol"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("PeerSession <|.. ConnectionProtocol"))
    }

    func test_clean_derivedAssociationLink_kept() {
        // Given: 新推导的关联线（-->）
        let input = "NetworkSDK --> User : uses"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("NetworkSDK --> User"))
    }

    func test_clean_derivedCompositionLink_kept() {
        // Given: 新推导的组合线（*--）
        let input = "User *-- Profile : owns"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("User *-- Profile"))
    }

    func test_clean_groupAggregateLine_kept() {
        // Given: group 之间的聚合线
        let input = "\"Core\" -- \"Domain\""

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("\"Core\" -- \"Domain\""))
    }

    func test_clean_memberLine_withPrimitiveTypeName_kept() {
        // Given
        let input = "class \"Foo\" as Foo { \n  +baseDelay : TimeInterval\n}"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("+baseDelay : TimeInterval"))
    }

    func test_clean_classDefinitionLine_kept() {
        // Given
        let input = "class \"PeerSession\" as PeerSession << (C, DarkSeaGreen) >> {"

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertTrue(output.contains("class \"PeerSession\""))
    }

    // MARK: - 整体

    func test_clean_multipleGhostLines_allRemoved() {
        // Given
        let input = """
        @startuml
        String -- Foo
        CaseIterable <|.. Foo
        "AnyObject" <|.. Bar
        Foo <|.. Bar
        @enduml
        """

        // When
        let output = OutputCleaner.clean(input)

        // Then
        XCTAssertEqual(output, """
        @startuml
        Foo <|.. Bar
        @enduml
        """)
    }
}
