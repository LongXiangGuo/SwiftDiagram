import ArgumentParser
import Foundation
import SwiftClassDiagramKit

extension SwiftClassDiagram {
    /// `swiftclassdiagram init` —— 生成一份带注释的配置 `.swiftplantuml.yml`。
    ///
    /// 默认（非交互）自动检测执行根目录的一级目录填充 include / exclude / groups；
    /// 加 `--custom` 进入交互模式，多选目录与启用的 group。
    struct Init: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Generate a .swiftplantuml.yml by auto-detecting root directories (or interactively with --custom)",
            helpNames: [.short, .long]
        )

        @Option(name: .shortAndLong, help: "Path to write the config (default: .swiftplantuml.yml in current directory)")
        var path: String?

        @Flag(name: .customLong("custom"), help: "Interactive mode: pick directories and enabled groups step by step")
        var custom: Bool = false

        @Flag(name: .shortAndLong, help: "Overwrite existing file")
        var force: Bool = false

        func run() throws {
            let target = path ?? ".swiftplantuml.yml"
            guard !FileManager.default.fileExists(atPath: target) || force else {
                throw CleanExit.message("\(target) already exists. Use --force to overwrite it.")
            }
            let yaml = custom ? try ConfigGenerator.interactiveYAML() : ConfigGenerator.nonInteractiveYAML()
            try yaml.write(toFile: target, atomically: true, encoding: .utf8)
            print("Generated configuration at \(target)")
        }
    }
}
