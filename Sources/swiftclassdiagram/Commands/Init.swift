import ArgumentParser
import Foundation
import SwiftClassDiagramKit

extension SwiftClassDiagram {
    /// `swiftclassdiagram init` —— 生成一份带注释的配置模板 `.swiftplantuml.yml`。
    struct Init: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Generate a documented .swiftplantuml.yml template (all sections explained, optional features disabled by default)",
            helpNames: [.short, .long]
        )

        @Option(name: .shortAndLong, help: "Path to write the template (default: .swiftplantuml.yml in current directory)")
        var path: String?

        @Flag(name: .shortAndLong, help: "Overwrite existing file")
        var force: Bool = false

        func run() throws {
            let target = path ?? ".swiftplantuml.yml"
            guard !FileManager.default.fileExists(atPath: target) || force else {
                throw CleanExit.message("\(target) already exists. Use --force to overwrite it.")
            }
            try ConfigTemplate.write(to: target)
            print("Generated configuration template at \(target)")
        }
    }
}
