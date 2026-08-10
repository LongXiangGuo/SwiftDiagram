import Foundation
import SwiftClassDiagramKit

/// 配置生成器：扫描执行根目录并生成 `.swiftplantuml.yml`。
///
/// 提供两种生成方式（对应 `init` / `serve` 的 `--custom` 开关）：
/// - 非交互（默认）：自动检测含 Swift 文件的一级目录作为 include 与 group，
///   全部 group 默认启用；无 Swift 文件的一级目录自动加入 exclude。
/// - 交互（`--custom`）：列出候选目录供多选，可选收缩到共同祖先，并按序号
///   选择启用的 group（未选择一律 `enable: false`）。
enum ConfigGenerator {
    // MARK: - 常量

    /// 模板内置排除项，任何生成方式都会写入 exclude。
    static let defaultExcludes: [String] = [".build/**", "Tests/**"]

    /// 目录候选。
    struct DirCandidate {
        /// 目录名（一级，相对根目录）。
        let name: String
        /// 目录内是否存在 Swift 文件（递归）。
        let hasSwift: Bool
        /// 是否被 `defaultExcludes` 排除。
        let excluded: Bool
    }

    enum GeneratorError: LocalizedError {
        case noCandidates
        case noInteractiveTerminal

        var errorDescription: String? {
            switch self {
            case .noCandidates:
                return "当前目录下未找到包含 Swift 文件的一级目录"
            case .noInteractiveTerminal:
                return "当前环境不支持交互输入，请去掉 --custom 使用非交互式生成"
            }
        }
    }

    // MARK: - 目录扫描

    /// 扫描根目录的一级子目录，过滤隐藏目录。
    static func scanCandidates(root: String = FileManager.default.currentDirectoryPath) -> [DirCandidate] {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.compactMap { url -> DirCandidate? in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let name = url.lastPathComponent
            guard isDir, !name.hasPrefix(".") else { return nil }
            return DirCandidate(
                name: name,
                hasSwift: directoryContainsSwiftFile(url),
                excluded: isDirectoryExcluded(url, by: defaultExcludes, relativeTo: root)
            )
        }.sorted { $0.name < $1.name }
    }

    // MARK: - 非交互式生成

    /// 非交互式生成配置内容：
    /// - include：含 Swift 且未被排除的一级目录逐条 `Dir/**/*.swift`（不含 `**/*.swift`）
    /// - exclude：模板内置排除项 + 无 Swift 文件的一级目录
    /// - groups：上述目录全部 `enable: true`
    static func nonInteractiveYAML(root: String = FileManager.default.currentDirectoryPath) -> String {
        let candidates = scanCandidates(root: root)
        let includable = candidates.filter { $0.hasSwift && !$0.excluded }
        let excluded = defaultExcludes + candidates.filter { !$0.hasSwift }.map { "\($0.name)/**" }
        let groups = includable.map { (name: $0.name, folder: $0.name, enable: true) }
        return buildYAML(
            include: includable.map { "\($0.name)/**/*.swift" },
            exclude: excluded,
            groups: groups
        )
    }

    // MARK: - 交互式生成

    /// 交互式生成配置内容（`--custom`）。
    ///
    /// 流程：候选目录多选 → 收集方式选择（逐条 / 收缩到共同祖先 / 全部）→
    /// 按序号选择启用的 group。
    static func interactiveYAML(root: String = FileManager.default.currentDirectoryPath) throws -> String {
        let candidates = scanCandidates(root: root).filter { $0.hasSwift && !$0.excluded }
        guard !candidates.isEmpty else { throw GeneratorError.noCandidates }

        print("扫描到以下含 Swift 文件的一级目录：")
        for (index, candidate) in candidates.enumerated() {
            print("  [\(index + 1)] \(candidate.name)")
        }
        print("  [0] 全部")
        print("请输入要收集的目录序号（逗号分隔，0=全部，直接回车=全部）: ", terminator: "")
        let dirInput = readLine() ?? ""
        let selected = parseIndexes(dirInput, count: candidates.count)
            .map { candidates[$0].name }

        let common = commonAncestor(of: selected)
        let commonText = common.isEmpty ? "." : common
        print("""
        收集方式：
          [1] 逐条列出选中目录（默认）
          [2] 收缩到共同祖先「\(commonText)」
          [3] 全部（**/*.swift）

        请选择: 
        """, terminator: "")
        let modeInput = readLine() ?? ""

        let include: [String]
        switch modeInput.trimmingCharacters(in: .whitespaces) {
        case "2":
            include = common.isEmpty ? ["**/*.swift"] : ["\(common)/**/*.swift"]
        case "3":
            include = ["**/*.swift"]
        default:
            include = selected.isEmpty ? candidates.map { "\($0.name)/**/*.swift" } : selected.map { "\($0)/**/*.swift" }
        }

        print("以下为自动检测的 group（选择启用的，未选择的一律 enable: false）：")
        for (index, candidate) in candidates.enumerated() {
            print("  [\(index + 1)] \(candidate.name)")
        }
        print("请输入要启用的 group 序号（逗号分隔，直接回车=全部启用）: ", terminator: "")
        let groupInput = readLine() ?? ""
        let enabled = parseIndexes(groupInput, count: candidates.count)
        let groups = candidates.enumerated().map {
            (name: $0.element.name, folder: $0.element.name, enable: enabled.contains($0.offset))
        }

        let excluded = defaultExcludes + scanCandidates(root: root)
            .filter { !$0.hasSwift }
            .map { "\($0.name)/**" }
        return buildYAML(include: include, exclude: excluded, groups: groups)
    }

    // MARK: - 交互辅助

    /// 解析序号输入（逗号分隔），空输入 = 全部；`0` = 全部。
    private static func parseIndexes(_ input: String, count: Int) -> [Int] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(0..<count) }
        let parts = trimmed.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.contains(0) { return Array(0..<count) }
        return parts.compactMap { $0 >= 1 && $0 <= count ? $0 - 1 : nil }
    }

    /// 计算若干相对路径的最深公共祖先（空表示无公共前缀）。
    static func commonAncestor(of paths: [String]) -> String {
        guard !paths.isEmpty else { return "" }
        let components = paths.map { $0.split(separator: "/").map(String.init) }
        var prefix: [String] = []
        let minLength = components.map(\.count).min() ?? 0
        outer: for index in 0..<minLength {
            let component = components[0][index]
            for path in components where path[index] != component { break outer }
            prefix.append(component)
        }
        return prefix.joined(separator: "/")
    }

    // MARK: - YAML 组装

    /// 按动态 files / groups 组装完整配置文本（elements 等板块使用静态骨架）。
    static func buildYAML(
        include: [String],
        exclude: [String],
        groups: [(name: String, folder: String, enable: Bool)]
    ) -> String {
        let includeLines = include.isEmpty
            ? "    \"**/*.swift\""
            : include.map { "    \"\($0)\"," }.joined(separator: "\n")
        let excludeLines = exclude.isEmpty
            ? "  exclude: []"
            : "  exclude: [\n" + exclude.map { "    \"\($0)\"" }.joined(separator: ",\n") + "\n  ]"
        let groupLines = groups.isEmpty
            ? "  groups: []"
            : "  groups:\n" + groups.map { group in
                """
                    - name: \(group.name)
                      folder: \(group.folder)
                      enable: \(group.enable)
                """
            }.joined(separator: "\n")

        return """
        # ============================================================
        # SwiftClassDiagram 配置文件
        # 生成：swiftclassdiagram init / serve（自动检测执行根目录的一级目录）
        #
        # 全部字段均可省略，省略即用默认值。
        # ============================================================

        # ---------- 1. 文件收集规则 (files) ----------
        # include / exclude 均为 glob 列表；include 留空 = 收集全部 Swift 文件。
        files:
          include: [
        \(includeLines)
          ]
        \(excludeLines)

        # ---------- 2. 元素规则 (elements) ----------
        # 控制类型与成员在类图中的可见性。
        elements:
          # 默认排除这些类型（支持通配符 *），过滤系统通用类型避免类图被淹没
          exclude:
            - "Date"
            - "String"
            - "Int"
            - "Double"
            - "Bool"
            - "Array*"
            - "Dictionary*"
            - "Optional*"
            - "Result*"
            - "Error"
            - "Codable*"
            - "Decodable*"
            - "Encodable*"
            - "URL*"
            - "Data"
            - "Notification*"
            - "Dispatch*"
            - "AnyPublisher*"
            - "PassthroughSubject*"
            - "CurrentValueSubject*"
            - "Publisher*"
            - "Subscriber*"
            - "Cancellable*"
            - "AnyCancellable"
            - "View"
            - "Text"
            - "Image"
            - "Color"
            - "Font"
            - "State*"
            - "Binding*"
            - "ObservedObject*"
            - "StateObject*"
            - "EnvironmentObject*"
            - "Environment*"
            - "PreferenceKey*"
            - "Shape*"
            - "Style*"
            - "ScrollView*"
            - "List*"
            - "Button*"
            - "Toggle*"
            - "Observable*"

          # 类型本身按访问级别过滤：true = 该访问级别的类型会绘制。
          havingAccessLevel:
            open: true
            public: true
            internal: true
            fileprivate: false     # 默认关闭（不绘制 fileprivate 类型）
            private: false         # 默认关闭（不绘制 private 类型）

          # 成员（方法/属性）按访问级别过滤，结构同上。
          showMembersWithAccessLevel:
            open: true
            public: true
            internal: true
            fileprivate: false
            private: false

          # 以下可选功能默认关闭（disable），按需打开：
          showNestedTypes: false   # 是否绘制嵌套类型
          showExtensions: false    # 是否绘制 extension
          showGenerics: false      # 是否绘制泛型参数

          # 五类关系开关（默认仅 inheritance 开启，其余 disable）
          relationships:
            inheritance:           # 继承 + 协议实现（<|-- / <|..）
              toggle: true
              exclude: []          # 排除的关系目标类型，支持通配符 *
            association:           # 关联：方法签名引用（-->）
              toggle: false        # 默认关闭，需要时改为 true
              exclude: []
            aggregation:           # 聚合：属性/初始化器依赖，非拥有语义（o--）
              toggle: false
              exclude: []
            composition:           # 组合：属性/初始化器依赖，拥有语义（*--）
              toggle: false
              exclude: []
            dependency:            # 扩展依赖：extension 与主类型连接（<..）
              toggle: false
              exclude: []

        # ---------- 3. 分组设置 (groupSettings) ----------
        # 按文件夹把类型聚合为 UML package；group 级配置可覆盖全局规则。
        groupSettings:
          # 分组定义（自动检测的一级目录）。
        \(groupLines)

          # group 级 elements 覆盖（优先级最高，仅启用任意 group 时生效）
          elements:
            enable: false           # 是否启用 group 级覆盖
            exclude: ["$(inherit)"] # $(inherit) = 继承全局 exclude 并追加
            # havingAccessLevel / showMembersWithAccessLevel / showNestedTypes /
            # showExtensions / showGenerics / relationships 均可在此覆盖（结构同全局 elements）

          # 跨 group 关系规则（默认全部关闭）
          crossGroupRelationships:
            inheritance: false
            association: false
            aggregation: false
            composition: false
            dependency: false
            singleLine:             # 跨 group 关系聚合为 group 间单行链接
              excludeSameGroup: true  # 同组内关系不受影响
              allGroups: true         # 任意跨 group 关系对只输出一条链接

        # ---------- 4. PlantUML skinparam 命令 (skinparamCommands) ----------
        # 追加到输出脚本末尾的 skinparam 命令，按需增删。
        skinparamCommands:
          - "skinparam shadow false"
          - "skinparam classWidth 120"
        """
    }
}
