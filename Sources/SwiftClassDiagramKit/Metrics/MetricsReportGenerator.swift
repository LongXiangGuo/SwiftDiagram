import Foundation

/// 生成设计复杂度与模块耦合度量报告。
///
/// 与类图生成共享同一套文件收集与规则解析（`folderRules` / `classRules` / `groups`），
/// 因此报告中的「模块」与类图中的分组一致。
public struct MetricsReportGenerator {
    /// default initializer
    public init() {}

    /// 从 Swift 源文件集合生成度量报告。
    /// - Parameters:
    ///   - paths: 源文件 / 目录路径（空数组 = 当前目录）
    ///   - configuration: 配置（含文件夹规则 / 类规则 / 分组）
    ///   - sdkPath: MacOSX SDK 路径（类型推断解析，可选）
    /// - Returns: 度量报告
    public func generate(for paths: [String], with configuration: Configuration = .default, sdkPath: String? = nil) -> MetricsReport {
        let directory = FileManager.default.currentDirectoryPath
        let files = FileCollector().getFiles(for: paths, in: directory, honoring: configuration.files)

        var allValidItems: [SyntaxStructure] = []
        var fileCount = 0
        for aFile in files {
            guard let validItems = SyntaxStructure.create(from: aFile, sdkPath: sdkPath)?.substructure else { continue }
            // 注入文件路径与字段级合并规则（与类图生成一致）
            validItems.forEach { item in
                item.filePath = aFile.path
                item.resolvedRule = ResolvedRule.resolve(
                    typeName: item.fullName ?? item.name ?? "",
                    filePath: aFile.path,
                    configuration: configuration
                )
            }
            allValidItems.append(contentsOf: validItems)
            fileCount += 1
        }
        return MetricsCollector.collect(items: allValidItems, fileCount: fileCount)
    }
}
