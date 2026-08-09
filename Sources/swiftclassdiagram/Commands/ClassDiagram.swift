import ArgumentParser
import Foundation
import SwiftClassDiagramKit
import Yams

extension SwiftClassDiagram {
    struct ClassDiagram: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "classdiagram",
            abstract: "Generate PlantUML script from Swift source code",
            helpNames: [.short, .long]
        )

        @Option(help: "Path to custom configuration file (otherwise will search for `.swiftplantuml.yml` in current directory)")
        var config: String?

        @Option(help: "paths to ignore source files. Takes precedence over arguments")
        var exclude = [String]()

        @Option(help: ArgumentHelp(
            "Defines output format. Options: \(ClassDiagramOutput.allCases.map(\.rawValue).joined(separator: ", "))",
            valueName: "format"
        ))
        var output: ClassDiagramOutput?

        @Option(help: "MacOSX SDK path used to handle type inference resolution, usually `$(xcrun --show-sdk-path -sdk macosx)`")
        var sdk: String?

        @Flag(help: "Apply built-in output cleanup (remove enum raw-value links, ghost types and collapse multi-line members)")
        var cleanup: Bool = false

        @Flag(help: "Verbose")
        var verbose: Bool = false

        @Argument(help: "List of paths to the files or directories containing swift sources")
        var paths = [String]()

        mutating func run() {
            Logger.shared = ConsoleLogger.create(verbose: verbose)

            var allPaths: [String]
            if !paths.isEmpty {
                allPaths = paths
            } else {
                allPaths = [] // Lint files in current working directory if no paths were specified.
            }

            var config = ConfigurationProvider().getConfiguration(for: self.config)

            if !exclude.isEmpty {
                config.files.exclude = exclude
            }

            Logger.shared.info("SDK: \(sdk ?? "no SDK path provided")")

            let directory = FileManager.default.currentDirectoryPath
            let files = FileCollector().getFiles(for: allPaths, in: directory, honoring: config.files)

            let generator = ClassDiagramGenerator()

            switch output {
            case .browserImageOnly:
                generator.generate(for: files.map(\.path), with: config, presentedBy: PlantUMLBrowserPresenter(format: .png), sdkPath: sdk)
            case .consoleOnly:
                let presenter = PlantUMLConsolePresenter()
                if cleanup {
                    // 内建清洗：与 generate_classdagram.sh 中 sed 规则等价，避免外部文本 hack
                    generator.generate(for: files.map(\.path), with: config, presentedBy: CleanedPlantUMLConsolePresenter(), sdkPath: sdk)
                } else {
                    generator.generate(for: files.map(\.path), with: config, presentedBy: presenter, sdkPath: sdk)
                }
            default:
                generator.generate(for: files.map(\.path), with: config, presentedBy: PlantUMLBrowserPresenter(format: .default), sdkPath: sdk)
            }
        }
    }
}

/// 输出到控制台前先经过 `OutputCleaner` 清洗的 Presenter
public struct CleanedPlantUMLConsolePresenter: PlantUMLPresenting {
    public init() {}

    public func present(script: PlantUMLScript, completionHandler: @escaping () -> Void) {
        print(OutputCleaner.clean(script.text))
        completionHandler()
    }
}

extension ClassDiagramOutput: ExpressibleByArgument {}
