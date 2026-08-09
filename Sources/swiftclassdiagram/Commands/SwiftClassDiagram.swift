import ArgumentParser
import Foundation
import SwiftClassDiagramKit

/// 根命令：swiftclassdiagram —— 基于 SourceKit AST 生成 PlantUML 类图。
///
/// 移植自 SwiftPlantUML（MIT），核心依赖 SourceKitten 解析 Swift 声明结构。
struct SwiftClassDiagram: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swiftclassdiagram",
        abstract: "Generate PlantUML class diagram scripts from Swift source code (based on SwiftPlantUML, MIT)",
        version: SwiftClassDiagramKit.Version.current.value,
        subcommands: [ClassDiagram.self, Serve.self, Report.self],
        defaultSubcommand: ClassDiagram.self
    )
}
