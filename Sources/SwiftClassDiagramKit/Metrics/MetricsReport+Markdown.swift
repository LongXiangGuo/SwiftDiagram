import Foundation

/// Markdown 渲染：模块耦合矩阵 + 复杂度排名，便于直接贴入文档/评审。
public extension MetricsReport {
    /// 渲染为 Markdown 文本。
    /// - Parameter topRankCount: 复杂度排名展示条数（默认 20）
    func markdown(topRankCount: Int = 20) -> String {
        var lines: [String] = []
        lines.append("# Swift 类图度量报告")
        lines.append("")
        lines.append("- 生成时间：\(generatedAt)")
        lines.append("- 扫描文件：\(totalFileCount) 个")
        lines.append("- 类型总数：\(totalTypeCount) 个")
        lines.append("- 模块数量：\(modules.count) 个")
        lines.append("")

        lines.append(contentsOf: markdownCouplingMatrix())
        lines.append(contentsOf: markdownModules())
        lines.append(contentsOf: markdownComplexityRanking(topRankCount: topRankCount))
        return lines.joined(separator: "\n")
    }

    // MARK: - 模块耦合矩阵

    private func markdownCouplingMatrix() -> [String] {
        var lines: [String] = []
        lines.append("## 模块耦合矩阵（行为源、列为目标，数值 = 跨模块关系数）")
        lines.append("")
        let labels = couplingMatrix.labels
        guard !labels.isEmpty else {
            lines.append("_暂无分组/文件夹数据_")
            lines.append("")
            return lines
        }
        let header = "| 源 \\ 目标 |" + labels.map { " \($0) |" }.joined()
        let separator = "| :--- |" + Array(repeating: " :---: |", count: labels.count).joined()
        lines.append(header)
        lines.append(separator)
        for (i, row) in couplingMatrix.values.enumerated() {
            let cells = row.map { " \($0) |" }.joined()
            lines.append("| **\(labels[i])** |\(cells)")
        }
        lines.append("")
        return lines
    }

    // MARK: - 模块概览

    private func markdownModules() -> [String] {
        var lines: [String] = []
        lines.append("## 模块概览")
        lines.append("")
        lines.append("| 模块 | 类型数 | 依赖其它模块 | 被其它模块依赖 |")
        lines.append("| :--- | :---: | :--- | :--- |")
        for module in modules {
            let outgoing = module.outgoingCoupling.isEmpty
                ? "-"
                : module.outgoingCoupling.map { "\($0.key)(\($0.value))" }.sorted().joined(separator: ", ")
            let incoming = module.incomingCoupling.isEmpty
                ? "-"
                : module.incomingCoupling.map { "\($0.key)(\($0.value))" }.sorted().joined(separator: ", ")
            lines.append("| \(module.name) | \(module.typeCount) | \(outgoing) | \(incoming) |")
        }
        lines.append("")
        return lines
    }

    // MARK: - 复杂度排名

    private func markdownComplexityRanking(topRankCount: Int) -> [String] {
        var lines: [String] = []
        lines.append("## 设计复杂度排名（Top \(min(topRankCount, complexityRanking.count))）")
        lines.append("")
        lines.append("> 分数 = 属性 + 方法 + 2×继承 + 2×扩展 + 出边依赖")
        lines.append("")
        lines.append("| 排名 | 类型 | 种类 | 模块 | 复杂度 | 属性 | 方法 | 私有 | 公开 | 内部 | 静态 | 继承 | 扩展 |")
        lines.append("| :---: | :--- | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
        for (index, metric) in complexityRanking.prefix(topRankCount).enumerated() {
            lines.append(
                "| \(index + 1) | \(metric.displayName) | \(metric.kind) | \(metric.module) | "
                    + "\(metric.complexityScore) | \(metric.propertyCount) | \(metric.methodCount) | "
                    + "\(metric.privateMemberCount) | \(metric.publicMemberCount) | \(metric.internalMemberCount) | "
                    + "\(metric.staticMemberCount) | \(metric.inheritedTypeCount) | \(metric.extensionCount) |"
            )
        }
        lines.append("")
        return lines
    }
}
