import ArgumentParser
import Foundation
import SwiftClassDiagramKit

extension SwiftClassDiagram {
    /// `swiftclassdiagram report` —— 输出设计复杂度与模块耦合度量报告。
    struct Report: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "report",
            abstract: "Generate a metrics report (module coupling matrix + class complexity ranking) from Swift source code",
            helpNames: [.short, .long]
        )

        @Option(help: "Path to custom configuration file (otherwise will search for `.swiftplantuml.yml` in current directory)")
        var config: String?

        @Option(name: .shortAndLong, help: "Output format: json | markdown")
        var format: ReportFormat = .markdown

        @Option(help: "Number of complexity ranking entries shown (markdown only, default 20)")
        var top: Int = 20

        @Option(help: "MacOSX SDK path used to handle type inference resolution, usually `$(xcrun --show-sdk-path -sdk macosx)`")
        var sdk: String?

        @Flag(help: "Verbose")
        var verbose: Bool = false

        @Argument(help: "List of paths to the files or directories containing swift sources")
        var paths = [String]()

        func run() throws {
            Logger.shared = ConsoleLogger.create(verbose: verbose)

            let configuration = ConfigurationProvider().getConfiguration(for: config)
            let report = MetricsReportGenerator().generate(for: paths, with: configuration, sdkPath: sdk)

            switch format {
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(report)
                print(String(data: data, encoding: .utf8) ?? "{}")
            case .markdown:
                print(report.markdown(topRankCount: top))
            }
        }
    }
}

extension ReportFormat: ExpressibleByArgument {}

/// report 输出格式
enum ReportFormat: String, CaseIterable {
    /// JSON（机器可读，含全部类型详情）
    case json
    /// Markdown（耦合矩阵 + 复杂度排名表格）
    case markdown
}
