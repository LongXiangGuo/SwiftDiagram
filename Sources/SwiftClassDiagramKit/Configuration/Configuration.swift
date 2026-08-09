import Foundation

/// Access Level for Swift variables and methods, see https://docs.swift.org/swift-book/LanguageGuide/AccessControl.html
public enum AccessLevel: String, Codable {
    /// `open`
    case open
    /// `public`
    case `public`
    /// `package`
    case `package`
    /// `internal`
    case `internal`
    /// `private`
    case `private`
    /// `fileprivate`
    case `fileprivate`
}

// https://plantuml.com/class-diagram
/// Configuration options to influence the generation and visual representation of the class diagram
///
/// 与 `.swiftplantuml.yml` 模板一一对应：
/// - `files`：文件收集规则（include / exclude）
/// - `elements`：全局 elements 设置（最低优先级 P0）
/// - `groupSettings`：分组定义 + group 级覆盖（P1/P2）+ 跨 group 关系
/// - `skinparamCommands`：PlantUML skinparam 命令
public struct Configuration: Codable {
    /// memberwise initializer
    public init(
        files: FileOptions = FileOptions(),
        elements: ElementOptions = ElementOptions(),
        groupSettings: GroupSettings = GroupSettings(),
        skinparamCommands: [String]? = ["skinparam shadow false", "skinparam classWidth 120"]
    ) {
        self.files = files
        self.elements = elements
        self.groupSettings = groupSettings
        self.skinparamCommands = skinparamCommands
    }

    /// default configuration used if no configuration file was found
    public static let `default` = Configuration()

    /// options which files shall be considered for class diagram generation
    public var files = FileOptions()

    /// options which and how elements shall be considered for class diagram generation
    public var elements = ElementOptions()

    /// 分组设置：分组定义、group 级 elements 覆盖、跨 group 关系规则
    public var groupSettings = GroupSettings()

    /// add skinparam values to change colors and font of the drawing. See https://plantuml.com/skinparam for more details
    public var skinparamCommands: [String]?
}
