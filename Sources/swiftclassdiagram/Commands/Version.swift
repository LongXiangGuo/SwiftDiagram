import ArgumentParser
import SwiftClassDiagramKit

extension SwiftClassDiagram {
    struct Version: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Display the current version of SwiftClassDiagram")

        static var value: String { SwiftClassDiagramKit.Version.current.value }

        mutating func run() throws {
            print(Self.value)
        }
    }
}
